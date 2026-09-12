--!nonstrict
-- Shared between widget.luau and panel.luau (separate script instances; only
-- plain data helpers belong here, no noctalia.state/barWidget/panel calls).

local M = {}

function M.glyphForPort(port)
	local label = tostring(port and (port.description or port.name) or ""):lower()
	if label:find("headphone", 1, true) or label:find("headset", 1, true) then
		return "headphones"
	end
	if label:find("hdmi", 1, true) or label:find("displayport", 1, true) then
		return "device-tv"
	end
	if label:find("line", 1, true) or label:find("speaker", 1, true) then
		return "device-speaker"
	end
	return "volume"
end

function M.activePort(ports)
	for _, port in ipairs(type(ports) == "table" and ports or {}) do
		if port.active == true then
			return port
		end
	end
	return nil
end

return M
