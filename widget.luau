--!nonstrict
-- Bar widget: shows the active port's glyph, left-click opens the port panel
-- (see plugin.toml [widget.actions]).

local SNAPSHOT_KEY = "port_switcher_snapshot"

local snapshot = noctalia.state.get(SNAPSHOT_KEY) or {
	available = false,
	loading = true,
	sinkDescription = "",
	ports = {},
	error = "",
}

local function activePort(ports)
	for _, port in ipairs(type(ports) == "table" and ports or {}) do
		if port.active == true then
			return port
		end
	end
	return nil
end

local function glyphFor(port)
	local label = tostring(port and (port.description or port.name) or ""):lower()
	if label:find("headphone", 1, true) or label:find("headset", 1, true) then
		return "headphones"
	end
	if label:find("hdmi", 1, true) or label:find("displayport", 1, true) then
		return "device-tv"
	end
	return "volume"
end

local function render()
	local port = activePort(snapshot.ports)
	barWidget.setGlyph(glyphFor(port))
	barWidget.setGlyphColor(snapshot.available and "default" or "error")

	local label = port and tostring(port.description or port.name or "") or ""
	barWidget.setText(not barWidget.isVertical() and label or "")

	local tooltipItems = {
		{ key = noctalia.tr("widget.sink"), value = tostring(snapshot.sinkDescription or "") },
		{ key = noctalia.tr("widget.port"), value = label ~= "" and label or noctalia.tr("widget.no_port") },
	}
	barWidget.setTooltip(tooltipItems)
end

noctalia.state.watch(SNAPSHOT_KEY, function(value)
	if type(value) == "table" then
		snapshot = value
		render()
	end
end)

render()
