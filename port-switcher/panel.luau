--!nonstrict
-- Port picker panel: one full-width tile per selectable port on the default
-- output sink (e.g. "Headphones" / "Line Out"). The whole tile is the click
-- target for switching; a separate small "edit" button opens an inline
-- rename/re-icon editor for that port. Panel and service are separate script
-- contexts, so they only ever talk through noctalia.state (COMMAND_KEY /
-- SNAPSHOT_KEY).

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

local editingPort = nil
local editAlias = ""
local editIconKey = "automatic"
local render

local function sendCommand(action, values)
	local command = { action = action }
	if type(values) == "table" then
		for key, value in pairs(values) do
			command[key] = value
		end
	end
	noctalia.state.set(COMMAND_KEY, command)
end

local function findPort(name)
	for _, port in ipairs(snapshot.ports) do
		if port.name == name then
			return port
		end
	end
	return nil
end

local function iconOptionLabels()
	local labels = {}
	for _, option in ipairs(common.ICON_OPTIONS) do
		table.insert(labels, noctalia.tr("editor.icon_options." .. option.key))
	end
	return labels
end

local function iconOptionIndex(key)
	for index, option in ipairs(common.ICON_OPTIONS) do
		if option.key == key then
			return index - 1
		end
	end
	return 0
end

local function editor(port)
	return ui.column({ gap = 7, padding = 10, radius = 10, fill = "surface_variant/0.45", border = "primary/0.35", borderWidth = 1 }, {
		ui.row({ align = "center", gap = 8 }, {
			ui.glyph({ name = "edit", size = 16, color = "primary" }),
			ui.label({ text = noctalia.tr("editor.title"), fontWeight = "bold", flexGrow = 1 }),
			ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCancelEdit" }),
		}),
		ui.label({ text = noctalia.tr("editor.alias"), fontSize = 11, color = "on_surface_variant" }),
		ui.input({
			key = "alias-" .. tostring(port.name),
			value = editAlias,
			placeholder = port.description,
			onChange = "onEditAliasChange",
		}),
		ui.label({ text = noctalia.tr("editor.icon"), fontSize = 11, color = "on_surface_variant" }),
		ui.select({
			options = iconOptionLabels(),
			selectedIndex = iconOptionIndex(editIconKey),
			onChange = "onEditIconChange",
		}),
		ui.row({ justify = "end", gap = 8 }, {
			ui.button({ text = noctalia.tr("actions.cancel"), variant = "ghost", onClick = "onCancelEdit" }),
			ui.button({ text = noctalia.tr("actions.save"), glyph = "device-floppy", variant = "primary", onClick = "onSaveEdit" }),
		}),
	})
end

local function portTile(port)
	local unavailable = port.available == false
	local statusText = unavailable and noctalia.tr("panel.port_unavailable")
		or (port.active and noctalia.tr("panel.active") or noctalia.tr("panel.tap_to_switch"))

	local children = {
		ui.row({ align = "center", gap = 6 }, {
			ui.button({
				text = port.displayName,
				glyph = port.icon,
				variant = port.active and "primary" or "outline",
				enabled = not port.active and not unavailable and not snapshot.busy,
				tooltip = statusText,
				flexGrow = 1,
				onClick = function()
					sendCommand("set_port", { port = port.name })
				end,
			}),
			ui.button({
				glyph = "edit",
				variant = "ghost",
				controlSize = "sm",
				tooltip = noctalia.tr("actions.edit"),
				onClick = function()
					editingPort = port.name
					editAlias = port.displayName ~= port.description and port.displayName or ""
					editIconKey = port.iconKey or "automatic"
					render()
				end,
			}),
		}),
	}
	if editingPort == port.name then
		table.insert(children, editor(port))
	end
	return ui.column({ gap = 8 }, children)
end

render = function()
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
		local tiles = {}
		for _, port in ipairs(snapshot.ports) do
			table.insert(tiles, portTile(port))
		end
		-- The inline editor can make one tile much taller than the others; scroll
		-- the list instead of relying on the (host-fixed) panel height to fit it.
		table.insert(children, ui.scroll({ flexGrow = 1, gap = 8 }, tiles))
	end

	panel.render(ui.column({ flexGrow = 1, gap = 12 }, children))
end

noctalia.state.watch(SNAPSHOT_KEY, function(value)
	if type(value) == "table" then
		snapshot = value
		if editingPort ~= nil and findPort(editingPort) == nil then
			editingPort = nil
		end
		render()
	end
end)

function onOpen(_context)
	render()
end

function onCloseClicked()
	panel.close()
end

function onCancelEdit()
	editingPort = nil
	render()
end

function onEditAliasChange(value)
	editAlias = tostring(value or "")
end

function onEditIconChange(index, _label)
	local option = common.ICON_OPTIONS[(math.floor(tonumber(index) or 0)) + 1]
	editIconKey = option and option.key or "automatic"
end

function onSaveEdit()
	if editingPort == nil then
		return
	end
	sendCommand("update_port", {
		id = editingPort,
		alias = editAlias,
		icon = common.glyphForKey(editIconKey),
	})
	editingPort = nil
	render()
end
