--!nonstrict
-- Port picker panel: one card per selectable port on the default output sink
-- (e.g. "Headphones" / "Line Out"), the active one highlighted. Clicking a
-- card's action button sends a command to service.luau (separate script
-- context, so panels and the service only ever talk through
-- noctalia.state / onIpc). Card layout mirrors the device rows in the
-- community "Audio Switcher" plugin: a bordered/filled row with icon, name,
-- status, and a trailing action button.

local common = require("./common.luau")

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

local function portCard(port)
	local unavailable = port.available == false
	local statusText = unavailable and noctalia.tr("panel.port_unavailable")
		or (port.active and noctalia.tr("panel.active") or noctalia.tr("panel.tap_to_switch"))

	return ui.row({
		align = "center",
		gap = 10,
		padding = 8,
		radius = 10,
		borderWidth = 1,
		border = port.active and "primary" or "outline/0.55",
		fill = port.active and "primary/0.08" or "surface/0",
	}, {
		ui.glyph({
			name = common.glyphForPort(port),
			size = 18,
			color = port.active and "primary" or "on_surface_variant",
		}),
		ui.column({ flexGrow = 1, gap = 2 }, {
			ui.label({
				text = tostring(port.description or port.name or ""),
				fontWeight = "bold",
				maxLines = 1,
			}),
			ui.label({
				text = statusText,
				fontSize = 10,
				color = port.active and "primary" or "on_surface_variant",
				maxLines = 1,
			}),
		}),
		ui.button({
			text = port.active and noctalia.tr("panel.current") or noctalia.tr("panel.use"),
			variant = port.active and "ghost" or "primary",
			controlSize = "sm",
			enabled = not port.active and not unavailable and not snapshot.busy,
			onClick = function()
				sendCommand("set_port", { port = port.name })
			end,
		}),
	})
end

local function render()
	local children = {
		ui.row({ align = "center", gap = 8 }, {
			ui.glyph({ name = "headphones", size = 18, color = "primary" }),
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
		local cards = {}
		for _, port in ipairs(snapshot.ports) do
			table.insert(cards, portCard(port))
		end
		table.insert(children, ui.column({ gap = 8 }, cards))
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
