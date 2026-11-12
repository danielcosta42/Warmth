--=============================================================================
-- What the player does in the world: lights a kit, places a camp object, stands by a fire, opens Cooking.
-- Nothing here announces a campfire; it only fills the screen and, with consent, keeps presence fresh.
--=============================================================================
local _, W = ...
local Watch = {}
W.Watch = Watch

Watch.NEAR = 25 -- yards: by the fire
W.placed   = nil -- { obj, at, map, x, y }: the camp object this player placed, and where
W.lit      = nil -- { at, tier }: the kit the game saw this player light
W.cooking  = nil -- { at, ready, names }: what Cooking could make when its window was last open

-- spell id -> { "kit", tier } or { "object", index }. An item's spell is asked for until the client answers,
-- at most every 30 s, so a cast costs one table lookup.
local spells, pending, lastResolve = {}, nil, -1e9
local function Resolve()
	if not pending then
		pending = {}
		for tier, kit in ipairs(W.KITS) do pending[kit] = { "kit", tier } end
		for index, o in ipairs(W.OBJECTS) do pending[o[1]] = { "object", index } end
	end
	if not next(pending) or GetTime() - lastResolve < 30 then return end
	lastResolve = GetTime()
	local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
	if not f then return end
	for item, what in pairs(pending) do
		local ok, _, id = pcall(f, item)
		if ok and id then spells[id] = what; pending[item] = nil end
	end
end

-- The object this player put at this camp: placed within the hour, within reach of the fire. 0 otherwise.
function Watch:ObjectAt(camp)
	local p = W.placed
	if not p or time() - p.at > 3600 or p.map ~= camp.map then return 0 end
	local an, aw = W.World(p.map, p.x, p.y)
	local bn, bw = W.World(camp.map, camp.x, camp.y)
	if not (an and bn) or math.sqrt((an - bn) ^ 2 + (aw - bw) ^ 2) > self.NEAR * 2 then return 0 end
	return p.obj
end

-- The camp the player is standing at: the nearest one on this map within reach, not known to be another copy of
-- the zone. One fire at a time: a pile of camps on one spot must not multiply what this client sends.
function Watch:Near()
	for _, camp in ipairs(W.Camps:List()) do -- nearest first
		if camp.dist and camp.dist <= self.NEAR and camp.other ~= true and not camp.demo then return camp end
	end
end

local asked = false
function Watch:Tick()
	Resolve()
	local camp = self:Near()
	if camp then
		if camp.owner == W.me or W.db.consent == true then
			W.Net:Presence(camp.owner)
		elseif W.db.consent == nil and not asked then
			asked = true -- once a session, until the player answers
			W:Fire("CONSENT_NEEDED", camp)
		end
	end
	W.Net:Heartbeat()
end

local function OnCast(spellID)
	if W.IsSecret(spellID) or type(spellID) ~= "number" then return end
	Resolve()
	local what = spells[spellID]
	if not what then return end
	if what[1] == "kit" then
		W.lit = { at = time(), tier = what[2] }
		W:Fire("LIT", what[2])
	else
		local map, x, y = W.Position()
		if not map then return end
		W.placed = { obj = what[2], at = time(), map = map, x = x, y = y }
		local camp = Watch:Near()
		if camp then W.Net:Presence(camp.owner, true) end
		W:Fire("CAMPS")
	end
end

-- Cooking recipes that can be made right now, read while the Cooking window is open (the classic trade skill
-- API; where the client lacks it, W.cooking stays nil and the checklist says to open Cooking).
local function OnTradeSkill()
	if not (GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillInfo) then return end
	local ok, line = pcall(GetTradeSkillLine)
	local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(W.COOKING_SPELL))
		or (GetSpellInfo and GetSpellInfo(W.COOKING_SPELL))
	if not ok or W.IsSecret(line, name) or not name or line ~= name then return end
	local ready, names = 0, {}
	for i = 1, GetNumTradeSkills() or 0 do
		local recipe, kind, available = GetTradeSkillInfo(i)
		if kind ~= "header" and (tonumber(available) or 0) > 0 then
			ready = ready + 1
			if #names < 3 then names[#names + 1] = recipe end
		end
	end
	W.cooking = { at = time(), ready = ready, names = names }
	W:Fire("CAMPS")
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event, unit, _, spellID)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if not W.IsSecret(unit) and unit == "player" then OnCast(spellID) end
	else
		pcall(OnTradeSkill)
	end
end)
W:On("LOGIN", function()
	Resolve()
	C_Timer.NewTicker(10, function() Watch:Tick() end)
end)
