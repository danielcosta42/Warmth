--=============================================================================
-- What makes a camp a place people come back to: what it asks for, thanking the host, the host's warmth, the
-- guestbook, and which of a camp's benefits a player would really gain.
--=============================================================================
local _, W = ...
local Social = {}
W.Social = Social

-- The buff objects (skill 20), in the order a camp asks for them: the tent first, then the widest buffs.
Social.WANT_ORDER = { W.TENT, 33, 7, 1, 4, 30, 13, 19, 22, 25 }
Social.WANTS_MAX = 6

-- The class buff each camp buff does not stack with (spell ids from the guides; matched by name, so any rank).
W.CLASS_BUFF = { [1] = 19742, [4] = 8075, [7] = 1126, [13] = 1459, [19] = 19740, [22] = 24907, [25] = 14752, [30] = 1243, [33] = 20217 }

-- A host's warmth: one point per person who thanks them, once a day each. Levels at these points.
Social.LEVELS = { "Kindling", "Ember", "Hearth", "Bonfire", "Beacon" }
Social.STEPS = { 3, 10, 25, 60, 150 }
Social.BOOK_MAX = 30

local function Today() return math.floor(time() / 86400) end

function Social:Level(points)
	local level = 0
	for i, step in ipairs(self.STEPS) do
		if (points or 0) >= step then level = i end
	end
	return level
end
function Social:MyLevel() return self:Level(W.db.heat.points) end

-- What a camp still lacks among the buff objects, most wanted first; nothing once every place is taken.
function Social:Wants(camp)
	local out, free = {}, W.SLOTS[camp.tier] - #W.Camps:Objects(camp)
	for _, index in ipairs(self.WANT_ORDER) do
		if #out < math.min(free, self.WANTS_MAX) and not W.Camps:Has(camp, index) then out[#out + 1] = index end
	end
	return out
end

-- Someone thanked this player for their fire. True when it counted (a new person today).
function Social:Thanked(who)
	local heat = W.db.heat
	if heat.thanks[who] == Today() then return false end
	local before = self:MyLevel()
	heat.thanks[who] = Today()
	heat.points = heat.points + 1
	W:Fire("THANKED", who, heat.points, self:MyLevel() > before and self:MyLevel() or nil)
	return true
end

-- May this player thank the host of this camp: sitting in someone else's circle, and not thanked them today.
function Social:CanThank(camp)
	return camp.owner ~= W.me and not camp.demo and not camp.spotted and camp.heard[W.me] ~= nil and W.db.thanked[camp.owner] ~= Today()
end
function Social:MarkThanked(owner) W.db.thanked[owner] = Today() end

-- The guestbook: a line for each camp this player sat at (once per camp).
function Social:Visit(camp)
	local book = W.db.guestbook
	local last = book[1]
	if last and last.owner == camp.owner and math.abs(last.lit - camp.at) < 60 then
		last.n = math.max(last.n, W.Camps:Count(camp))
		return false
	end
	table.insert(book, 1, { owner = camp.owner, map = camp.map, at = time(), lit = camp.at, n = W.Camps:Count(camp) })
	while #book > self.BOOK_MAX do table.remove(book) end
	return true
end

-- The class buff the player already carries that this camp object's buff would not stack with: its name, or nil.
function Social:AlreadyHave(index)
	local spell = W.CLASS_BUFF[index]
	local name = spell and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)) or (GetSpellInfo and GetSpellInfo(spell)))
	if type(name) ~= "string" or W.IsSecret(name) then return nil end
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then return nil end
	for i = 1, 40 do
		local ok, aura = pcall(get, "player", i, "HELPFUL")
		if not ok or type(aura) ~= "table" then break end
		if not W.IsSecret(aura.name) and aura.name == name then return name end
	end
	return nil
end

-- A camp asks for objects: is one of them something this player carries or can craft? index, "bags" | "craft".
function Social:CanAnswer(camp)
	for _, index in ipairs(camp.wants or {}) do
		if W.Count(W.OBJECTS[index][1]) > 0 then return index, "bags" end
	end
	for _, index in ipairs(camp.wants or {}) do
		local entry = W.Workshop:Object(index)
		if entry and (entry.state == "ready" or entry.state == "materials") then return index, "craft" end
	end
end

W:On("LOADED", function()
	local db = W.db
	db.heat = type(db.heat) == "table" and db.heat or {}
	db.heat.points, db.heat.thanks = tonumber(db.heat.points) or 0, type(db.heat.thanks) == "table" and db.heat.thanks or {}
	db.thanked = type(db.thanked) == "table" and db.thanked or {}
	db.guestbook = type(db.guestbook) == "table" and db.guestbook or {}
	for name, day in pairs(db.heat.thanks) do -- yesterday's thanks no longer block today's
		if day ~= Today() then db.heat.thanks[name] = nil end
	end
	for owner, day in pairs(db.thanked) do
		if day ~= Today() then db.thanked[owner] = nil end
	end
end)
