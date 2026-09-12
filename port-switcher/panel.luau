--!nonstrict
-- Port picker panel: one tile per selectable port on the default output sink
-- (e.g. "Headphones" / "Line Out"), the active one highlighted. Clicking a
-- tile sends a command to service.luau (separate script context, so panels
-- and the service only ever talk through noctalia.state / onIpc).

local SNAPSHOT_KEY = "port_switcher_snapshot"
local COMMAND_KEY = "port_switcher_command"

local snapshot = noctalia.state.get(SNAPSHOT_KEY) or {
	available = false,
	loading = true,
	busy = false,
	sinkDescription = "",
	ports = {},
	error = "",
}

local function sendCommand(action, values)
	local command = { action = action }
	if type(values) == "table" then
		for key, value in pairs(values) do
			command[key] = value
		end
	end
	noctalia.state.set(COMMAND_KEY, command)
end

local function portTile(port)
	return ui.button({
		text = tostring(port.description or port.name or ""),
		variant = port.active and "primary" or "outline",
		enabled = not snapshot.busy and port.available ~= false,
		tooltip = port.available == false and noctalia.tr("panel.port_unavailable") or nil,
		flexGrow = 1,
		onClick = function()
			sendCommand("set_port", { port = port.name })
		end,
	})
end

local function render()
	local children = {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.label({ text = noctalia.tr("title"), fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
			ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
		}),
		ui.label({
			text = tostring(snapshot.sinkDescription or ""),
			fontSize = 11,
			color = "on_surface_variant",
			maxLines = 1,
		}),
	}

	if snapshot.loading then
		table.insert(children, ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }))
	elseif not snapshot.available then
		local message = tostring(snapshot.error) ~= "" and tostring(snapshot.error) or noctalia.tr("panel.unavailable")
		table.insert(children, ui.label({ text = message, color = "error" }))
	elseif #snapshot.ports < 2 then
		table.insert(children, ui.label({ text = noctalia.tr("panel.no_ports"), color = "on_surface_variant" }))
	else
		local tiles = {}
		for _, port in ipairs(snapshot.ports) do
			table.insert(tiles, portTile(port))
		end
		table.insert(children, ui.row({ gap = 8, wrap = true }, tiles))
	end

	panel.render(ui.column({ flexGrow = 1, gap = 12 }, children))
end

noctalia.state.watch(SNAPSHOT_KEY, function(value)
	if type(value) == "table" then
		snapshot = value
		render()
	end
end)

function onOpen(_context)
	render()
end

function onCloseClicked()
	panel.close()
end
