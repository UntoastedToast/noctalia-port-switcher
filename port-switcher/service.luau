--!nonstrict
-- Port Switcher backend. The service is the sole owner of pactl subprocesses;
-- the widget and panel only read published state and send commands through
-- shared state (COMMAND_KEY) or onIpc (compositor keybinds).

local SNAPSHOT_KEY = "port_switcher_snapshot"
local COMMAND_KEY = "port_switcher_command"
local REFRESH_INTERVAL_MS = 3000

local snapshot = {
	available = false,
	loading = true,
	busy = false,
	sinkName = "",
	sinkDescription = "",
	ports = {},
	error = "",
	revision = 0,
}

local refreshPending = false
local refreshAgain = false
local actionBusy = false

local function trim(value)
	return noctalia.string.trim(tostring(value or ""))
end

local function shellQuote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function runPactl(args, callback, timeoutMs)
	local parts = { "env", "LC_ALL=C", "pactl" }
	for _, value in ipairs(args) do
		table.insert(parts, value)
	end
	local quoted = {}
	for _, value in ipairs(parts) do
		table.insert(quoted, shellQuote(value))
	end
	local started = noctalia.runAsync(table.concat(quoted, " "), callback, timeoutMs or 15000)
	if not started and type(callback) == "function" then
		callback({
			exitCode = -1,
			stdout = "",
			stderr = noctalia.tr("errors.command_start"),
			timedOut = false,
		})
	end
	return started
end

local function decodeJson(value)
	local decoded, err = noctalia.json.decode(tostring(value or ""))
	if type(decoded) ~= "table" then
		noctalia.log("port-switcher: JSON decode failed: " .. tostring(err or "unknown error"))
		return nil
	end
	return decoded
end

local function portText(value)
	return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

-- pactl's JSON sink object carries `active_port` (a table, or sometimes just the
-- port name string) and a `ports` array of {name, description, availability}.
local function parsePorts(sink)
	local activeValue = type(sink.active_port) == "table" and sink.active_port.name or sink.active_port
	local activeName = portText(activeValue)
	local ports = {}
	for _, port in ipairs(type(sink.ports) == "table" and sink.ports or {}) do
		if type(port) == "table" then
			local name = portText(port.name)
			if name ~= "" then
				local description = portText(port.description)
				local availability = portText(port.availability):lower()
				table.insert(ports, {
					name = name,
					description = description ~= "" and description or name,
					-- pactl reports "not available" only when jack-sense actively detects
					-- nothing plugged in; treat every other value as selectable.
					available = availability ~= "not available",
					active = name == activeName,
				})
			end
		end
	end
	return ports
end

local function findSink(sinks, name)
	for _, item in ipairs(sinks) do
		if tostring(item.name or "") == name then
			return item
		end
	end
	return nil
end

local function publishSnapshot()
	snapshot.busy = actionBusy
	snapshot.revision += 1
	noctalia.state.set(SNAPSHOT_KEY, snapshot)
end

local function refreshAll()
	if refreshPending then
		refreshAgain = true
		return
	end
	refreshPending = true
	refreshAgain = false
	publishSnapshot()

	if not noctalia.commandExists("pactl") then
		snapshot.available = false
		snapshot.loading = false
		snapshot.error = noctalia.tr("errors.pactl_missing")
		refreshPending = false
		publishSnapshot()
		return
	end

	runPactl({ "-f", "json", "info" }, function(infoResult)
		if infoResult.exitCode ~= 0 then
			snapshot.available = false
			snapshot.loading = false
			snapshot.error = trim(infoResult.stderr)
			refreshPending = false
			publishSnapshot()
			if refreshAgain then
				refreshAll()
			end
			return
		end

		local info = decodeJson(infoResult.stdout)
		local defaultSink = info and tostring(info.default_sink_name or "") or ""

		runPactl({ "-f", "json", "list", "sinks" }, function(sinkResult)
			refreshPending = false
			if sinkResult.exitCode ~= 0 then
				snapshot.available = false
				snapshot.loading = false
				snapshot.error = trim(sinkResult.stderr)
				publishSnapshot()
				if refreshAgain then
					refreshAll()
				end
				return
			end

			local sinks = decodeJson(sinkResult.stdout) or {}
			local sink = findSink(sinks, defaultSink)
			if sink == nil then
				snapshot.available = false
				snapshot.sinkName = ""
				snapshot.sinkDescription = ""
				snapshot.ports = {}
				snapshot.error = noctalia.tr("errors.no_default_sink")
			else
				snapshot.available = true
				snapshot.sinkName = defaultSink
				snapshot.sinkDescription = tostring(sink.description or defaultSink)
				snapshot.ports = parsePorts(sink)
				snapshot.error = ""
			end
			snapshot.loading = false
			publishSnapshot()
			if refreshAgain then
				refreshAll()
			end
		end)
	end)
end

local function setPort(portName)
	if actionBusy then
		return
	end
	if trim(snapshot.sinkName) == "" or trim(portName) == "" then
		return
	end
	actionBusy = true
	publishSnapshot()
	runPactl({ "set-sink-port", snapshot.sinkName, portName }, function(result)
		actionBusy = false
		if result.exitCode ~= 0 then
			local message = trim(result.stderr)
			noctalia.notifyError(
				noctalia.tr("title"),
				message ~= "" and message or noctalia.tr("errors.switch_failed")
			)
			publishSnapshot()
			refreshAll()
			return
		end
		refreshAll()
	end)
end

function onIpc(event, payload)
	if event == "set_port" then
		setPort(tostring(payload or ""))
	elseif event == "refresh" then
		refreshAll()
	end
end

noctalia.state.watch(COMMAND_KEY, function(command)
	if type(command) == "table" and command.action == "set_port" then
		setPort(tostring(command.port or ""))
	end
end)

if noctalia.commandExists("pactl") then
	local streamStarted = noctalia.runStream("LC_ALL=C pactl subscribe", function(line)
		local text = tostring(line)
		if text:find(" on sink #", 1, true) ~= nil or text:find(" on server", 1, true) ~= nil then
			refreshAll()
		end
	end)
	if not streamStarted then
		noctalia.log("port-switcher: could not subscribe to pactl events")
	end
end

noctalia.setUpdateInterval(REFRESH_INTERVAL_MS)

function update()
	refreshAll()
end

refreshAll()
