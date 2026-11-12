--=============================================================================
-- What the player does in the world: lights a kit, places a camp object, stands by a fire, opens Cooking.
-- Nothing here announces a campfire; it only fills the screen and, with consent, keeps presence fresh.
--=============================================================================
local _, W = ...
local Watch = {}
W.Watch = Watch

Watch.NEAR = 25 -- yards: by the fire
W.placed   = nil -- { obj, at, map, x, y }: the camp object this player placed, and where
W.lit      = nil -- { at, tier, map, x, y }: the kit the game saw this player light, and where (kept across a /reload)
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
		-- a camp marked "no fire here" stays in the running: standing there is how the mark gets cleared
		if camp.dist and camp.dist <= self.NEAR and (camp.other ~= true or camp.notHere) and not camp.demo then return camp end
	end
end

-- How long a campfire burns is not published (guides say 10 or 15 minutes). This client times its own: from the
-- kit's cast to the moment the game's Campfire Nearby aura drops, provided the player stayed by the fire all
-- along. The answer, per tier, is kept in WarmthDB.burn (seconds, to the tick's 10 s).
local burning
local function TimeTheFire()
	local b = burning
	if not b then return end
	local fire = W.FireNearby()
	local map, x, y = W.Position()
	local an, aw = W.World(b.map, b.x, b.y)
	local pn, pw
	if map == b.map then pn, pw = W.World(map, x, y) end
	if fire == nil or not (an and pn) or math.sqrt((an - pn) ^ 2 + (aw - pw) ^ 2) > Watch.NEAR then
		burning = nil -- walked away, or the client cannot tell: this one is not a measurement
	elseif fire then
		b.seen = GetTime()
	elseif b.seen then
		burning = nil
		local seconds = math.floor(b.seen - b.t0 + 5)
		W.db.burn = W.db.burn or {}
		W.db.burn[b.tier] = seconds
		W:Fire("BURNED", b.tier, seconds)
	end
end

-- The fire this player lit, if they are standing by it: its tier is then known without asking.
function Watch:MyFire()
	local lit = W.lit
	if not (lit and lit.map) or time() - lit.at > 3600 then return nil end
	local map, x, y = W.Position()
	if map ~= lit.map then return nil end
	local an, aw = W.World(lit.map, lit.x, lit.y)
	local pn, pw = W.World(map, x, y)
	if not (an and pn) or math.sqrt((an - pn) ^ 2 + (aw - pw) ^ 2) > Watch.NEAR * 2 then return nil end
	return lit
end

-- A fire lit by someone without Warmth is unknown to the network until a player who has it stops by: the game
-- says "a campfire is near" (the aura), the addon knows of no camp around, so this client announces it as a
-- sighting. Only for a player standing still by it (two ticks), not one riding past, and only with the automatic
-- announce on. Where it is and what tier are this player's guess: their own position, Basic until they point at
-- the fire. The lighter's own announce, or an earlier sighting, replaces it.
local function Apart(a, map, x, y)
	if a.map ~= map then return nil end
	local an, aw = W.World(a.map, a.x, a.y)
	local bn, bw = W.World(map, x, y)
	return an and bn and math.sqrt((an - bn) ^ 2 + (aw - bw) ^ 2) or nil
end

local still
function Watch:Sight()
	local mine = W.Camps:Get(W.me)
	if mine and mine.spotted then
		for _, other in ipairs(W.Camps:List()) do
			local d = other ~= mine and not other.demo and other.other ~= true and Apart(other, mine.map, mine.x, mine.y)
			if d and d <= W.Net.OWNER_NEAR and (not other.spotted or other.owner < mine.owner) then
				W.Net:End()
				return false
			end
		end
		return false
	end
	if mine or W.db.auto == false or W.FireNearby() ~= true or self:MyFire() then still = nil; return false end
	for _, camp in ipairs(W.Camps:List()) do
		if camp.dist and camp.dist <= W.Net.OWNER_NEAR and camp.other ~= true and not camp.demo then still = nil; return false end
	end
	local map, x, y = W.Position()
	if not map then still = nil; return false end
	-- a sighting that ended while its fire still burned (the player's click, or someone else's word) is not made again
	-- there for an hour
	local last = self.lastSight
	local again = last and GetTime() - last.t < 3600 and Apart(last, map, x, y)
	if again and again <= W.Net.OWNER_NEAR then return false end
	local moved = still and Apart(still, map, x, y)
	if not (moved and moved <= 5) then
		still = { map = map, x = x, y = y }
		return false
	end
	still = nil
	local camp = W.Net:Announce(1, "", true)
	if not camp then return false end
	self.lastSight = { map = map, x = x, y = y, t = GetTime() }
	W:Fire("SIGHTED", camp)
	return true
end

local asked = false
function Watch:Tick()
	Resolve()
	TimeTheFire()
	if W.FireNearby() == false and self:MyFire() then -- standing where I lit it, and it is gone
		W.lit, W.db.lit = nil, nil
		W:Fire("CAMPS")
	end
	local camp = self:Near()
	if camp and W.FireNearby() == false then
		-- Standing where the camp is, and the game shows no fire: it went out, or it burns in another copy of the
		-- zone. Two ticks in a row, so a moment of lag is not taken for it.
		camp.gone = (camp.gone or 0) + 1
		if camp.gone >= 2 then
			if camp.owner == W.me then
				local found = camp.spotted
				W.Net:End() -- my fire went out: the announce goes with it
				if found then Watch.lastSight = nil else W:Fire("FIRE_OUT") end
			else
				camp.notHere = true
				W:Fire("CAMPS")
			end
		end
		camp = nil -- nobody is in the circle of a fire that is not there
	elseif camp then
		if camp.gone or camp.notHere then
			camp.gone, camp.notHere = nil, nil
			W:Fire("CAMPS")
		end
	end
	if camp then
		local violet = W.HasAura(W.AURA.VIOLET)
		if violet ~= nil and (camp.violetSeen == true) ~= violet then
			camp.violetSeen = violet or nil
			W:Fire("CAMPS")
		end
		if camp.owner == W.me or W.db.consent == true then
			W.Net:Presence(camp.owner)
		elseif W.db.consent == nil and not asked then
			asked = true -- once a session, until the player answers
			W:Fire("CONSENT_NEEDED", camp)
		end
	end
	self:Sight()
	W.Net:Heartbeat()
end

local function OnCast(spellID)
	if W.IsSecret(spellID) or type(spellID) ~= "number" then return end
	if spellID == W.VIOLET_DUST_SPELL then W.db.violetToy = true end -- the player owns the toy: the ring offers it
	Resolve()
	local what = spells[spellID]
	if not what then return end
	if what[1] == "kit" then
		local map, x, y = W.Position()
		W.lit = { at = time(), tier = what[2], map = map, x = x, y = y }
		W.db.lit = W.lit
		burning = map and { tier = what[2], t0 = GetTime(), map = map, x = x, y = y } or nil
		W:Fire("LIT", what[2])
		if W.db.auto ~= false then
			-- The network learns of a campfire as it is lit, unless the player turned that off. A moment later, so
			-- the game has put its Campfire Nearby aura on the player and the announce is of a real fire.
			local tier = what[2]
			C_Timer.After(1.5, function()
				if W.db.auto == false or W.FireNearby() == false then return end
				local camp = W.Net:Announce(tier, "")
				if camp then W:Fire("AUTO_ANNOUNCED", camp) end
			end)
		end
	else
		local map, x, y = W.Position()
		if not map then return end
		W.placed = { obj = what[2], at = time(), map = map, x = x, y = y }
		local camp = Watch:Near()
		if camp then W.Net:Presence(camp.owner, true) end
		W:Fire("CAMPS")
	end
end

-- Cooking recipes that can be made right now, read while the Cooking window is open. Forever has the modern
-- C_TradeSkillUI and not the classic GetTradeSkill* globals (measured); both are tried, guarded. Where neither
-- answers, W.cooking stays nil and the checklist says to open Cooking.
local function OnTradeSkill()
	local cooking = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(W.COOKING_SPELL))
		or (GetSpellInfo and GetSpellInfo(W.COOKING_SPELL))
	if W.IsSecret(cooking) or not cooking then return end
	local ready, names = 0, {}
	local function add(recipe, available)
		if W.IsSecret(recipe, available) or (tonumber(available) or 0) <= 0 then return end
		ready = ready + 1
		if #names < 3 and type(recipe) == "string" then names[#names + 1] = recipe end
	end
	local TS = C_TradeSkillUI
	if TS and TS.GetBaseProfessionInfo and TS.GetAllRecipeIDs and TS.GetRecipeInfo then
		local base = TS.GetBaseProfessionInfo()
		if type(base) ~= "table" or W.IsSecret(base.professionName) then return end
		if base.professionName ~= cooking and base.parentProfessionName ~= cooking then return end
		for _, id in ipairs(TS.GetAllRecipeIDs() or {}) do
			local info = TS.GetRecipeInfo(id)
			if type(info) == "table" and info.learned ~= false then add(info.name, info.numAvailable) end
		end
	elseif GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillInfo then
		if GetTradeSkillLine() ~= cooking then return end
		for i = 1, GetNumTradeSkills() or 0 do
			local recipe, kind, available = GetTradeSkillInfo(i)
			if kind ~= "header" then add(recipe, available) end
		end
	else
		return
	end
	W.cooking = { at = time(), ready = ready, names = names }
	W:Fire("CAMPS")
end

-- A piece someone without Warmth placed is invisible to the addon, except for one thing the client does say: the
-- name of the world object under the mouse (measured 2026-11-12: "Camp Tent", "Chair", "Basic Campfire"; the
-- object's name can drop the item's "Camp "). Pointing at a piece while standing at a camp notes it there.
function Watch:Spot(text)
	if W.IsSecret(text) or type(text) ~= "string" or text == "" then return nil end
	local camp = self:Near()
	if not camp then return nil end
	if camp.owner == W.me and camp.spotted then -- the fire I found says its tier (enUS names, as measured)
		for tier, name in ipairs(W.TIERS) do
			if text == name .. " Campfire" and camp.tier ~= tier then
				camp.tier = tier
				W:Fire("CAMPS")
			end
		end
	end
	for i, o in ipairs(W.OBJECTS) do
		if text == o[2] or text == W.ObjectName(i) or "Camp " .. text == o[2] then
			camp.seen = camp.seen or {}
			if not camp.seen[i] then
				camp.seen[i] = true
				W:Fire("CAMPS")
				if camp.owner == W.me then W.Net:Extras() end -- my camp no longer asks for it
			end
			return i
		end
	end
	return nil
end

local lastTip
local function PollTooltip()
	local tip = _G.GameTooltip
	if not (tip and tip:IsShown() and tip:GetOwner() == UIParent and tip:NumLines() == 1) then lastTip = nil; return end
	local fs = _G.GameTooltipTextLeft1
	local text = fs and fs:GetText()
	if W.IsSecret(text) or text == lastTip then return end
	lastTip = text
	Watch:Spot(text)
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
W:On("LOADED", function()
	local lit = W.db.lit
	if type(lit) == "table" and type(lit.at) == "number" and W.SLOTS[lit.tier or 0] and time() - lit.at < 3600 then W.lit = lit
	else W.db.lit = nil end
end)
W:On("LOGIN", function()
	C_Timer.NewTicker(0.5, function() pcall(PollTooltip) end)
	Resolve()
	C_Timer.NewTicker(10, function() Watch:Tick() end)
end)
