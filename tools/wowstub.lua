-- A simulated WoW: Forever client for the harnesses in tools/. Not a harness itself.
--
--   local S = dofile("tools/wowstub.lua")
--   local W = S.load("Core/")          -- runs the toc's files whose path starts with one of the given prefixes
--   S.fire("PLAYER_LOGIN")             -- to every frame registered for it
--   S.advance(30)                      -- moves the clock, running timers and tickers on the way
--
-- Frames, textures, font strings and animations are one generic widget: it keeps text, size, scale, alpha,
-- shown state, points and scripts; any other capitalised method is a no-op. A lower-case field that was never set
-- is nil, as on a real frame.
local S = { now = 1000, timers = {}, frames = {}, sent = {}, bags = {}, spells = {}, printed = {},
	pos = { map = 1411, x = 0.5, y = 0.5 }, copy = 0, guild = true, tooltip = {} }
local EPOCH = 1790000000

function GetTime() return S.now end
function time() return EPOCH + math.floor(S.now) end
date = os.date
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	S.printed[#S.printed + 1] = table.concat(parts, " ")
end
function geterrorhandler() return function(err) error(err, 0) end end

C_Timer = {
	After = function(d, fn) S.timers[#S.timers + 1] = { at = S.now + d, fn = fn } end,
	NewTicker = function(d, fn)
		local t = { at = S.now + d, fn = fn, every = d }
		S.timers[#S.timers + 1] = t
		return { Cancel = function() t.dead = true end }
	end,
}
function S.advance(seconds)
	local target = S.now + seconds
	while true do
		table.sort(S.timers, function(a, b) return a.at < b.at end)
		local t = S.timers[1]
		if not t or t.at > target then break end
		table.remove(S.timers, 1)
		S.now = t.at
		if not t.dead then
			if t.every then t.at = t.at + t.every; S.timers[#S.timers + 1] = t end
			t.fn()
		end
	end
	S.now = target
end

function strsplit(sep, s, limit)
	local out, start = {}, 1
	while true do
		if limit and #out == limit - 1 then out[#out + 1] = s:sub(start); break end
		local i = s:find(sep, start, true)
		if not i then out[#out + 1] = s:sub(start); break end
		out[#out + 1] = s:sub(start, i - 1)
		start = i + #sep
	end
	return unpack(out)
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
function GetLocale() return S.locale or "enUS" end
function UnitName() return "Chehul" end
function UnitFullName() return "Chehul", "Costa" end
function UnitClass() return "Druid", "DRUID" end
function UnitFactionGroup() return S.faction or "Horde" end
function GetPlayerFacing() return S.facing or 0 end
function GetCVar(name) return S.cvars and S.cvars[name] or "0" end
function IsInGuild() return S.guild end
function InCombatLockdown() return S.combat or false end
-- professions as GetProfessions / GetProfessionInfo report them: S.profs = { { name, rank, max, line } }
function GetProfessions() local out = {}; for i in ipairs(S.profs or {}) do out[i] = i end; return unpack(out) end
function GetProfessionInfo(i) local p = (S.profs or {})[i]; if p then return p[1], "icon", p[2], p[3], 0, 0, p[4] end end
function IsPlayerSpell(id) return (S.known or {})[id] == true end
function UnitGUID(unit) return unit == "npc" and S.npc or nil end
function GetMerchantNumItems() return #(S.merchant or {}) end
function GetMerchantItemID(i) return (S.merchant or {})[i] end
function GetBuildInfo() return "1.60.1", "70862", "", 16001 end
function IsInGroup() return false end
function IsInRaid() return false end
C_PlayerInfo = { ShouldDisplaySurname = function() return true end }
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
CLASS_ICON_TCOORDS = { DRUID = { 0.74, 0.99, 0, 0.25 }, MAGE = { 0.25, 0.49, 0, 0.25 } }
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
SlashCmdList, UISpecialFrames = {}, {}
C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
C_PartyInfo = { InviteUnit = function(name) S.invited = name end }
C_Item = {
	GetItemCount = function(id) return S.bags[id] or 0 end,
	GetItemSpell = function(id) return "spell", id + 1000000 end, -- every item casts "its id + a million"
	GetItemIconByID = function(id) return "icon" .. id end,
}
C_Spell = { GetSpellName = function(id) return id == 2550 and "Cooking" or nil end }

-- A 5000 x 5000 yard zone on continent 1414, which is 20000 yards wide; world x grows north, y grows west.
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
C_Map = {
	GetBestMapForUnit = function() return S.pos and S.pos.map or nil end,
	GetPlayerMapPosition = function() return S.pos and vec(S.pos.x, S.pos.y) or nil end,
	-- Mulgore (1412) lies 6000 yards east of Durotar (1411) here, so the two zones do not overlap.
	GetWorldPosFromMapPos = function(map, v)
		local x, y = v:GetXY()
		return 1, vec(-y * 5000, -(x * 5000 + (map == 1412 and 6000 or 0)))
	end,
	GetMapPosFromWorldPos = function(_, v, map)
		local n, w = v:GetXY()
		if map == 1414 then return map, vec(0.25 + (-w) / 20000, 0.25 + (-n) / 20000) end
		return map, vec((-w - (map == 1412 and 6000 or 0)) / 5000, -n / 5000)
	end,
	GetMapInfo = function(map) return { name = ({ [1411] = "Durotar", [1412] = "Mulgore", [1414] = "Kalimdor" })[map] or ("Zone" .. map), parentMapID = 1414 } end,
	SetUserWaypoint = function(p) S.waypoint = p end,
}
C_SuperTrack = { SetSuperTrackingUserWaypoint = function() end }

local filters = {}
function ChatFrame_AddMessageEventFilter(event, fn) filters[event] = fn end
S.filters = filters

-- ── widgets ────────────────────────────────────────────────────────────────
local Widget
local METHODS = {
	CreateTexture = function(self) local w = Widget(); w.parent = self; return w end,
	CreateFontString = function(self) local w = Widget(); w.parent = self; return w end,
	CreateMaskTexture = function() return Widget() end,
	CreateAnimationGroup = function() return Widget() end,
	CreateAnimation = function() return Widget() end,
	SetText = function(self, s) self.text = s end, GetText = function(self) return self.text end,
	GetStringWidth = function(self) return #tostring(self.text or "") * 6 end,
	GetStringHeight = function() return 14 end,
	SetWidth = function(self, v) self.w = v end, GetWidth = function(self) return self.w end,
	SetHeight = function(self, v) self.h = v end, GetHeight = function(self) return self.h end,
	SetSize = function(self, a, b) self.w, self.h = a, b end,
	SetScale = function(self, v) self.scale = v end, GetScale = function(self) return self.scale or 1 end,
	SetAlpha = function(self, v) self.alpha = v end, GetAlpha = function(self) return self.alpha or 1 end,
	SetTexture = function(self, v) self.texture = v end,
	SetTexCoord = function(self, ...) self.coords = { ... } end,
	SetVertexColor = function(self, ...) self.color = { ... } end,
	SetPoint = function(self, ...) self.point = { ... } end, ClearAllPoints = function(self) self.point = nil end,
	GetFrameLevel = function() return 1 end,
	GetCenter = function() return 300, 200 end, GetEffectiveScale = function() return 1 end,
	SetAttribute = function(self, k, v) self.attributes = self.attributes or {}; self.attributes[k] = v end,
	SetRotation = function(self, v) self.rotation = v end,
	GetOwner = function() return nil end,
	-- like the client, a change of visibility runs the frame's OnShow / OnHide
	Show = function(self)
		local was = self.shown
		self.shown = true
		if was == false and self.scripts.OnShow then self.scripts.OnShow(self) end
	end,
	Hide = function(self)
		local was = self.shown
		self.shown = false
		if was ~= false and self.scripts.OnHide then self.scripts.OnHide(self) end
	end,
	SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
	IsShown = function(self) return self.shown end,
	IsVisible = function(self)
		local f = self
		while f do
			if f.shown == false then return false end
			f = f.parent
		end
		return true
	end,
	SetScript = function(self, k, fn) self.scripts[k] = fn end, GetScript = function(self, k) return self.scripts[k] end,
	HookScript = function(self, k, fn) self.scripts[k] = fn end,
	RegisterEvent = function(self, e) self.events[e] = true end,
	SetChecked = function(self, v) self.checked = v and true or false end, GetChecked = function(self) return self.checked end,
	SetVerticalScroll = function(self, v) self.scroll = v end, GetVerticalScroll = function(self) return self.scroll or 0 end,
	Click = function(self, button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end,
}
Widget = function()
	return setmetatable({ scripts = {}, events = {}, text = "", w = 100, h = 20, shown = true }, {
		__index = function(_, k) return METHODS[k] or (type(k) == "string" and k:match("^%u") and function() end or nil) end })
end
S.Widget = Widget
function CreateFrame(_, name, parent, template)
	local f = Widget()
	f.parent, f.template = parent, template
	S.frames[#S.frames + 1] = f
	if name then _G[name] = f end
	return f
end
UIParent, Minimap = Widget(), Widget()
UIParent.w, UIParent.h, Minimap.w, Minimap.h = 1920, 1080, 140, 140
function Minimap:GetZoom() return S.zoom or 0 end
GameTooltip = Widget()
function GameTooltip:SetText(s) S.tooltip = { s } end
function GameTooltip:AddLine(s) S.tooltip[#S.tooltip + 1] = s end
WorldMapFrame = Widget()
WorldMapFrame.shown = false
S.canvas = Widget()
S.canvas.w, S.canvas.h = 1000, 600
function WorldMapFrame.OnMapChanged() end
function hooksecurefunc(_, name, fn) S.hooks = S.hooks or {}; S.hooks[name] = fn end
function WorldMapFrame:GetCanvas() return S.canvas end
function WorldMapFrame:GetMapID() return S.shownMap or 1411 end
Settings = {
	RegisterCanvasLayoutCategory = function(panel, name) S.category = { panel = panel, name = name }; return S.category end,
	RegisterAddOnCategory = function(cat) S.registered = cat end,
	OpenToCategory = function() S.openedOptions = true end,
}

function S.fire(event, ...)
	for _, f in ipairs(S.frames) do
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end
-- Runs every frame's OnUpdate once (the per-frame drivers).
function S.frame(elapsed)
	for _, f in ipairs(S.frames) do
		if f.scripts.OnUpdate and f:IsVisible() then f.scripts.OnUpdate(f, elapsed or 0.1) end
	end
end

-- ── the mesh ───────────────────────────────────────────────────────────────
local mesh = {}
local function record(bus) return function(_, prefix, payload, a, b)
	S.sent[#S.sent + 1] = { bus = bus, prefix = prefix, payload = payload, target = bus == "Whisper" and a or nil, relay = bus == "Realm" and b or nil }
	return true
end end
mesh.Guild, mesh.Group, mesh.Whisper, mesh.Realm = record("Guild"), record("Group"), record("Whisper"), record("Realm")
function mesh:Register(prefix, fn) S.handler, S.prefix = fn, prefix end
function mesh:Relayable(prefix) S.relayable = prefix end
function mesh:PeerStore(fn) S.peerStore = fn end
_G.ChehulMesh = mesh
_G.ChehulNet = {
	peers = {},
	Register = function(_, tag, caps) S.tag, S.caps = tag, caps end,
	RegisterDiag = function(_, tag, fn) S.diagTag, S.diag = tag, fn end,
	MyLayer = function() return S.pos and S.pos.map or 0, S.copy end,
}
-- What was sent since the last call, optionally only one bus.
function S.take(bus)
	local out = {}
	for _, m in ipairs(S.sent) do
		if not bus or m.bus == bus then out[#out + 1] = m end
	end
	S.sent = {}
	return out
end

-- Loads the addon as the game does: the toc's order, (ADDON, namespace) as the chunk's arguments.
function S.load(...)
	local prefixes, W = { ... }, {}
	for line in io.lines("Warmth.toc") do
		local path = line:match("^([%w/_%.%-]+%.lua)%s*$")
		for _, prefix in ipairs(prefixes) do
			if path and path:sub(1, #prefix) == prefix then
				local chunk = assert(loadfile(path))
				chunk("Warmth", W)
			end
		end
	end
	return W
end

local checks = 0
function S.check(cond, what)
	checks = checks + 1
	if not cond then io.stderr:write("FAIL: " .. tostring(what) .. "\n"); os.exit(1) end
end
function S.done(name) io.write(string.format("%s: %d checks passed\n", name, checks)) end

return S
