--!nonstrict
-- Shared between service.luau and panel.luau (separate script instances; only
-- plain data helpers belong here, no noctalia.state/barWidget/panel calls).

local M = {}

-- Curated icon choices offered in the panel's per-port editor. Plugins have no
-- access to Noctalia's native glyph-picker dialog (that's a C++-only control),
-- so this is a hand-picked list of glyphs relevant to audio ports rather than
-- a full Tabler Icons browser. All verified present in
-- assets/fonts/tabler.json on the host.
M.ICON_OPTIONS = {
	{ key = "automatic", glyph = "" },
	{ key = "headphones", glyph = "headphones" },
	{ key = "headset", glyph = "headset" },
	{ key = "speaker", glyph = "device-speaker" },
	{ key = "airpods", glyph = "device-airpods" },
	{ key = "microphone", glyph = "microphone" },
	{ key = "bluetooth", glyph = "bluetooth" },
	{ key = "tv", glyph = "device-tv" },
	{ key = "music", glyph = "music" },
}

function M.iconKeyForGlyph(glyph)
	glyph = tostring(glyph or "")
	for _, option in ipairs(M.ICON_OPTIONS) do
		if option.glyph == glyph then
			return option.key
		end
	end
	return "automatic"
end

function M.glyphForKey(key)
	for _, option in ipairs(M.ICON_OPTIONS) do
		if option.key == key then
			return option.glyph
		end
	end
	return ""
end

-- Best-effort automatic glyph, used when a port has no manual icon override.
function M.autoGlyphForPort(port)
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
