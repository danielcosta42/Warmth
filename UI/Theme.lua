--=============================================================================
-- The look: warm night, firelight. Colours, fonts and where the textures are.
--=============================================================================
local _, W = ...
local UI = {}
W.UI = UI

local T = {
	night  = { 0.070, 0.047, 0.031 }, -- the window
	panel  = { 0.140, 0.086, 0.050 }, -- raised surfaces
	raised = { 0.215, 0.135, 0.080 },
	line   = { 0.330, 0.215, 0.130 },
	ember  = { 1.000, 0.705, 0.330 }, -- the accent: firelight
	deep   = { 0.940, 0.480, 0.150 },
	text   = { 0.955, 0.905, 0.825 },
	mute   = { 0.780, 0.655, 0.510 },
	faint  = { 0.520, 0.400, 0.290 },
	ok     = { 0.640, 0.830, 0.490 },
	miss   = { 1.000, 0.610, 0.490 },
	copy   = { 0.560, 0.690, 0.860 }, -- "another copy of the zone": the one cool colour
}
UI.T = T
UI.MEDIA = "Interface\\AddOns\\Warmth\\Media\\"
UI.CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"

function UI.Hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end
UI.C = { ember = UI.Hex(T.ember), mute = UI.Hex(T.mute), ok = UI.Hex(T.ok), miss = UI.Hex(T.miss), copy = UI.Hex(T.copy),
	text = UI.Hex(T.text), r = "|r" }

-- The title face is Latin only: other clients keep the game's own font, which has their glyphs (and their
-- players' names).
local LATIN = { enUS = true, enGB = true, ptBR = true, ptPT = true, esES = true, esMX = true, frFR = true, deDE = true, itIT = true }
local body = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
function UI.Font(kind)
	if kind == "title" and LATIN[GetLocale and GetLocale() or "enUS"] then return UI.MEDIA .. "Fonts\\YoungSerif-Regular.ttf" end
	return body
end

function UI.ClassColor(classIndex)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[W.CLASSES[classIndex or 0] or ""]
	if c then return { c.r, c.g, c.b } end
	return T.mute
end
