--=============================================================================
-- What the player does in the world: lights a kit, places a camp object, stands by a fire, opens Cooking.
-- Nothing here announces a campfire; it only fills the screen and, with consent, keeps presence fresh.
--=============================================================================
local _, W = ...
local Watch = {}
W.Watch = Watch

Watch.NEAR = 25 -- yards: by the fire
W.myObject = 0  -- index of the object this player placed this session
W.lit      = nil -- { at, tier }: the kit the game saw this player light
W.cooking  = nil -- { at, ready, names }: what Cooking could make when its window was last open

local function ItemSpell(item)
	local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
	if not f then return nil end
	local ok, _, id = pcall(f, item)
	return ok and id or nil
end

-- Camps the player is standing at: same map, within reach, and not known to be another copy of the zone.
function Watch:Near()
	local out = {}
	for _, camp in ipairs(W.Camps:List()) do
		if camp.dist and camp.dist <= self.NEAR and camp.other ~= true and not camp.demo then out[#out + 1] = camp end
	end
	return out
end

local asked = false
function Watch:Tick()
	for _, camp in ipairs(self:Near()) do
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
	for tier, kit in ipairs(W.KITS) do
		if ItemSpell(kit) == spellID then
			W.lit = { at = time(), tier = tier }
			W:Fire("LIT", tier)
			return
		end
	end
	for index, o in ipairs(W.OBJECTS) do
		if ItemSpell(o[1]) == spellID then
			W.myObject = index
			for _, camp in ipairs(Watch:Near()) do W.Net:Presence(camp.owner) end
			W:Fire("CAMPS")
			return
		end
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
	C_Timer.NewTicker(10, function() Watch:Tick() end)
end)
