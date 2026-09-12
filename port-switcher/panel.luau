--!nonstrict
-- Port picker panel: a row of icon+name buttons, one per selectable port on
-- the default output sink, laid out like a segmented control. Left-click a
-- button to switch to that port; right-click it to rename it or change its
-- icon inline (onRightClick only exists on ui.button, so this has to be a
-- button, not a richer row/card - see portButton()). Panel and service are
-- separate script contexts, so they only ever talk through noctalia.state
-- (COMMAND_KEY / SNAPSHOT_KEY).

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

local function startEditing(port)
	editingPort = port.name
	editAlias = port.displayName ~= port.description and port.displayName or ""
	editIconKey = port.iconKey or "automatic"
	render()
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

-- Icon + name button per port, laid out in a row like a segmented control.
-- Left-click switches; right-click opens the rename/icon editor (rendered
-- once, below the whole row - see render()). Status goes in the tooltip -
-- there's no room for a second line on a button.
local function portButton(port)
	local unavailable = port.available == false
	local clickable = not port.active and not unavailable and not snapshot.busy
	local statusText = unavailable and noctalia.tr("panel.port_unavailable")
		or (port.active and noctalia.tr("panel.active") or noctalia.tr("panel.tap_to_switch"))

	return ui.button({
		text = port.displayName,
		glyph = port.icon,
		variant = port.active and "primary" or "outline",
		enabled = not unavailable and not snapshot.busy,
		flexGrow = 1,
		tooltip = statusText .. " · " .. noctalia.tr("panel.right_click_hint"),
		onClick = clickable and function()
			sendCommand("set_port", { port = port.name })
		end or nil,
		onRightClick = function()
			startEditing(port)
		end,
	})
end

render = function()
	local header = ui.row({ align = "center", gap = 8 }, {
		ui.glyph({ name = "headphones", size = 18, color = "primary" }),
		ui.label({ text = noctalia.tr("title"), fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
		ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
	})

	local body = {
		ui.label({
			text = tostring(snapshot.sinkDescription or ""),
			fontSize = 11,
			color = "on_surface_variant",
			maxLines = 1,
		}),
	}

	if snapshot.loading then
		table.insert(body, ui.label({ text = noctalia.tr("panel.loading"), color = "on_surface_variant" }))
	elseif not snapshot.available then
		local message = tostring(snapshot.error) ~= "" and tostring(snapshot.error) or noctalia.tr("panel.unavailable")
		table.insert(body, ui.label({ text = message, color = "error" }))
	elseif #snapshot.ports < 2 then
		table.insert(body, ui.label({ text = noctalia.tr("panel.no_ports"), color = "on_surface_variant" }))
	else
		local buttons = {}
		for _, port in ipairs(snapshot.ports) do
			table.insert(buttons, portButton(port))
		end
		table.insert(body, ui.row({ gap = 8, wrap = true }, buttons))

		local editingPortData = editingPort ~= nil and findPort(editingPort) or nil
		if editingPortData ~= nil then
			table.insert(body, editor(editingPortData))
		end
	end

	-- Scroll the body (not the header): an open editor can make the content
	-- taller than the (host-fixed) panel height.
	panel.render(ui.column({ flexGrow = 1, gap = 12 }, { header, ui.scroll({ flexGrow = 1, gap = 12 }, body) }))
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
