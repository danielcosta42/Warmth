--=============================================================================
-- The Workshop: what the player could make for a camp, what is missing, and where to get it.
--
-- Everything here was measured with /warmth probe (2026-11-12, build 1.60.1.70888):
--   * GetProfessions / GetProfessionInfo give the player's professions and skill without opening anything;
--   * IsPlayerSpell(recipe spell) tells whether a camp recipe is learned;
--   * C_TradeSkillUI.GetRecipeSchematic(recipe) gives what it takes, with item ids and amounts;
--   * a merchant is known by the npc id in UnitGUID("npc") and lists its items with GetMerchantItemID.
--
-- Vendors of camp materials come from Core/VendorData.lua, the table generated from the QuestieDB of Forever
-- (tools/gen-questie.py), and from what the player and the network add to it: see "Vendors" below.
--=============================================================================
local _, W = ...
local Workshop = {}
W.Workshop = Workshop

-- Skill lines of the professions that make camp objects (the ids GetProfessionInfo reports).
W.PROF_LINE = { Alchemy = 171, Blacksmithing = 164, Enchanting = 333, Engineering = 202, Herbalism = 182,
	Leatherworking = 165, Mining = 186, Skinning = 393, Tailoring = 197, Cooking = 185, ["First Aid"] = 129, Fishing = 356 }

-- Skill each object asks for: 20, 140 and 300 in every profession; Cooking has only the last two.
W.SKILL = {}
do
	local nth, last = 0, nil
	for index, o in ipairs(W.OBJECTS) do
		nth = (o[3] == last) and nth + 1 or 1
		last = o[3]
		W.SKILL[index] = ({ 20, 140, 300 })[nth + (o[3] == "Cooking" and 1 or 0)]
	end
end

-- Where the blueprint of a higher object is reported to drop (one third-party guide; not verified). Proper names
-- of bosses and dungeons, shown as they are.
W.BLUEPRINT = {
	[2] = "Rath'mael, Ruins of Lordaeron", [5] = "Gilnid, The Deadmines", [8] = "Shade of the Archmage, City of Dalaran",
	[11] = "Sneed, The Deadmines", [14] = "Shadetooth, Excavation Site: Wetlands", [17] = "Razorclaw the Butcher, Shadowfang Keep",
	[20] = "Relic Guardian, Excavation Site: Wetlands", [23] = "Lady Anacondra, Wailing Caverns",
	[26] = "Unstable Sentinel, City of Dalaran", [28] = "Cookie, The Deadmines", [31] = "Commander Springvale, Shadowfang Keep",
	[34] = "Gelihast, Blackfathom Deeps",
}


local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local function results(ok, ...) if ok then return ... end end
	return results(pcall(fn, ...))
end

--------------------------------------------------------------------------------
-- Professions and recipes
--------------------------------------------------------------------------------
-- [skill line] = { name, rank, max } for the professions the player has.
function Workshop:Professions()
	local out = {}
	if not (GetProfessions and GetProfessionInfo) then return out end
	for _, index in pairs({ Call(GetProfessions) }) do
		local name, _, rank, max, _, _, line = Call(GetProfessionInfo, index)
		if not W.IsSecret(name, rank, line) and type(line) == "number" then out[line] = { name = name, rank = tonumber(rank) or 0, max = tonumber(max) or 0 } end
	end
	return out
end

-- What a camp object takes: { { item, need, have } }, or nil when the client does not say.
local schematics = {}
function Workshop:Reagents(index)
	local list = schematics[index]
	if not list then -- only an answer is kept: the client may not have the data yet when first asked
		local s = Call(C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic, W.RECIPES[index], false)
		if type(s) == "table" and type(s.reagentSlotSchematics) == "table" then
			local found = {}
			for _, slot in ipairs(s.reagentSlotSchematics) do
				local reagent = type(slot.reagents) == "table" and slot.reagents[1]
				if reagent and type(reagent.itemID) == "number" then found[#found + 1] = { item = reagent.itemID, need = tonumber(slot.quantityRequired) or 1 } end
			end
			if #found > 0 then list = found; schematics[index] = found end
		end
	end
	if not list then return nil end
	local out = {}
	for i, r in ipairs(list) do out[i] = { item = r.item, need = r.need, have = W.Count(r.item) } end
	return out
end

-- Where the player stands with one camp object, or nil when its profession is not theirs.
--   state "ready" (can = how many), "materials", "skill" (need / rank), "recipe" (source), "unknown" (materials not read)
function Workshop:Object(index, professions)
	local o = W.OBJECTS[index]
	local line = W.PROF_LINE[o[3]]
	local prof = (professions or self:Professions())[line]
	if not prof then return nil end
	local out = { index = index, line = line, profession = prof.name, rank = prof.rank, need = W.SKILL[index], bags = W.Count(o[1]) }
	out.reagents = self:Reagents(index)
	if prof.rank < out.need then
		out.state = "skill"
	elseif Call(IsPlayerSpell, W.RECIPES[index]) ~= true then
		out.state = "recipe"
	elseif not out.reagents then
		out.state = "unknown"
	else
		local can = math.huge
		for _, r in ipairs(out.reagents) do can = math.min(can, math.floor(r.have / r.need)) end
		out.can = can
		out.state = can > 0 and "ready" or "materials"
	end
	return out
end

-- Every camp object of the player's professions, the ones closest to done first.
local ORDER = { ready = 1, materials = 2, unknown = 3, recipe = 4, skill = 5 }
function Workshop:List()
	local out, professions = {}, self:Professions()
	for index in ipairs(W.OBJECTS) do
		local entry = self:Object(index, professions)
		if entry then out[#out + 1] = entry end
	end
	table.sort(out, function(a, b)
		if ORDER[a.state] ~= ORDER[b.state] then return ORDER[a.state] < ORDER[b.state] end
		return a.index < b.index
	end)
	return out
end

-- An object the player could craft that this camp still lacks: the entry, ready before missing materials.
function Workshop:CouldBring(camp)
	if #W.Camps:Objects(camp) >= W.SLOTS[camp.tier] then return nil end
	for _, entry in ipairs(self:List()) do
		if (entry.state == "ready" or entry.state == "materials") and not W.Camps:Has(camp, entry.index) then return entry end
	end
end

-- Opens the profession's window. False when the client has no such call or refuses it: the caller says so.
function Workshop:Open(line)
	local open = C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill
	if type(open) ~= "function" then return false end
	local ok, result = pcall(open, line)
	return ok and result ~= false
end

--------------------------------------------------------------------------------
-- Vendors
--
-- Three tiers of trust, because a message on the network can be forged and its sender is only claimed:
--   table   Core/VendorData.lua, generated from the QuestieDB;
--   mine    a vendor this player opened (W.db.vendors[npc].mine): it wins over the table, which may be wrong;
--   heard   a vendor someone on the network told about. Never about an npc the table knows, never over "mine",
--           used only for an item no trusted vendor sells, forgotten after two weeks, never passed on.
-- Nothing is sent when a vendor is opened (that would say where the player is right now): a vendor the table
-- lacks waits for the half-hourly gossip, at least ten minutes later, and only if the player lets it.
--------------------------------------------------------------------------------
Workshop.MINE_MAX, Workshop.HEARD_MAX, Workshop.HEARD_TTL = 200, 100, 14 * 86400
Workshop.TELL_AFTER = 600 -- seconds a vendor waits before it may be told

-- Items worth knowing a vendor for: the woods, what the table's vendors sell, what a camp recipe takes.
local wanted, wantedAt = nil, -1e9
function Workshop:Wanted()
	if wanted and GetTime() - wantedAt < 60 then return wanted end
	local set = { [4471] = true }
	for _, wood in ipairs(W.WOOD) do set[wood[1]] = true end
	for _, v in pairs(W.VENDOR_DATA or {}) do
		for _, item in ipairs(v[6]) do set[item] = true end
	end
	for index in ipairs(W.OBJECTS) do
		for _, r in ipairs(self:Reagents(index) or {}) do set[r.item] = true end
	end
	wanted, wantedAt = set, GetTime()
	return set
end

local nearest = {} -- [item] = { at, vendor, yards, heard }: the last answer of Workshop:Vendor, emptied when the book changes

function Workshop:Vendors()
	return W.db and W.db.vendors or {}
end

local function Close(a, b) -- the same spot, give or take a few steps
	return a.map == b.map and math.abs(a.x - b.x) < 0.03 and math.abs(a.y - b.y) < 0.03
end

-- Does the generated table already say this: the npc, about there, selling at least these items?
local function TableSays(npc, v)
	local t = W.VENDOR_DATA and W.VENDOR_DATA[npc]
	if not t or not Close({ map = t[2], x = t[3] / 10000, y = t[4] / 10000 }, v) then return false end
	local sold = {}
	for _, item in ipairs(t[6]) do sold[item] = true end
	for _, item in ipairs(v.items) do
		if not sold[item] then return false end
	end
	return true
end

-- Makes room among the entries of one kind (mine or heard), oldest out first, so one kind never starves the other.
local function MakeRoom(book, mine, max)
	local n, oldest, oldestAt = 0, nil, math.huge
	for npc, v in pairs(book) do
		if (v.mine == true) == mine then
			n = n + 1
			if (v.at or 0) < oldestAt then oldest, oldestAt = npc, v.at or 0 end
		end
	end
	if n >= max and oldest then book[oldest] = nil end
end

-- A vendor enters the book. Returns true when the book changed.
function Workshop:Learn(npc, v, mine)
	local book = W.db.vendors
	local old = book[npc]
	if mine then
		if TableSays(npc, v) then -- nothing the table lacks: no entry, nothing to tell
			if old and not old.mine then book[npc] = nil end
			return false
		end
	else
		if (W.VENDOR_DATA and W.VENDOR_DATA[npc]) or (old and old.mine) then return false end -- hearsay never corrects what is trusted
		if W.Sources.Avoid(v.map) then return false end
	end
	local items = v.items
	if old and not mine then -- what was heard before is kept: a shorter list does not erase a longer one
		local seen = {}
		items = {}
		for _, list in ipairs({ old.items, v.items }) do
			for _, item in ipairs(list) do
				if not seen[item] and #items < W.Wire.VENDOR_ITEMS then seen[item] = true; items[#items + 1] = item end
			end
		end
	end
	if old and Close(old, v) and #old.items == #items and (old.mine == true) == (mine == true) then
		old.at = time() -- the same thing again: still true, nothing to redraw
		return false
	end
	if not old then MakeRoom(book, mine == true, mine and self.MINE_MAX or self.HEARD_MAX) end
	book[npc] = { name = v.name, map = v.map, x = v.x, y = v.y, items = items, mine = mine or nil, at = time(), tell = mine or nil }
	nearest = {}
	W:Fire("VENDORS")
	return true
end

-- Vendors of an item the player can use. Trusted ones: the generated table (those friendly to the player's
-- faction) with the vendors the player opened laid over it. Only when there is none of those, and unless
-- `trustedOnly`, the ones heard on the network. Returns { [npc] = { name, map, x, y } } and whether they are hearsay.
local byItem
function Workshop:Sellers(item, trustedOnly)
	if not byItem then -- the generated table, indexed once
		byItem = {}
		local mine = (UnitFactionGroup and UnitFactionGroup("player") or ""):sub(1, 1)
		for npc, v in pairs(W.VENDOR_DATA or {}) do
			if mine == "" or v[5]:find(mine, 1, true) then
				for _, sold in ipairs(v[6]) do
					byItem[sold] = byItem[sold] or {}
					byItem[sold][npc] = { name = v[1], map = v[2], x = v[3] / 10000, y = v[4] / 10000 }
				end
			end
		end
	end
	local out, heard = {}, {}
	for npc, v in pairs(byItem[item] or {}) do out[npc] = v end
	for npc, v in pairs(self:Vendors()) do
		for _, sold in ipairs(v.items) do
			if sold == item then
				if v.mine then out[npc] = v -- seen in game: it wins over the database
				elseif time() - (v.at or 0) < self.HEARD_TTL then heard[npc] = v end
			end
		end
	end
	if next(out) or trustedOnly then return out, false end
	return heard, next(heard) ~= nil
end

-- The nearest vendor of an item: by yards when it is on the player's continent, otherwise the first by id.
-- vendor, yards (nil for another continent), heard (true when only the network says so). Cached a few seconds.
function Workshop:Vendor(item)
	local hit = nearest[item]
	if hit and GetTime() - hit.at < 5 then return hit.vendor, hit.yards, hit.heard end
	local map, x, y = W.Position()
	local pn, pw, pc
	if map then pn, pw, pc = W.World(map, x, y) end
	local best, bestYards, other, otherNpc
	local sellers, heard = self:Sellers(item)
	for npc, v in pairs(sellers) do
		local n, w, c = W.World(v.map, v.x, v.y)
		if pn and n and c == pc then
			local yards = math.sqrt((n - pn) ^ 2 + (w - pw) ^ 2)
			if not bestYards or yards < bestYards then best, bestYards = v, yards end
		elseif not otherNpc or npc < otherNpc then
			other, otherNpc = v, npc
		end
	end
	nearest[item] = { at = GetTime(), vendor = best or other, yards = best and bestYards or nil, heard = heard }
	return best or other, best and bestYards or nil, heard
end

-- A vendor this player opened that is ready to be told: not told yet, opened at least TELL_AFTER ago. npc or nil.
function Workshop:ToTell()
	for npc, v in pairs(self:Vendors()) do
		if v.mine and v.tell and time() - (v.at or 0) >= self.TELL_AFTER then return npc end
	end
end

-- The merchant window is open: if this npc sells camp materials the table does not know about, it is written
-- down. Nothing is sent here.
local function OnMerchant()
	local guid = Call(UnitGUID, "npc")
	if W.IsSecret(guid) or type(guid) ~= "string" then return end
	local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	npc = tonumber(npc)
	local map, x, y = W.Position()
	if kind ~= "Creature" or not npc or not map then return end
	local want, items = Workshop:Wanted(), {}
	for i = 1, math.min(tonumber(Call(GetMerchantNumItems)) or 0, 100) do
		local id = Call(GetMerchantItemID, i)
		if type(id) == "number" and want[id] and #items < W.Wire.VENDOR_ITEMS then items[#items + 1] = id end
	end
	if #items == 0 then return end
	local name = Call(UnitName, "npc")
	Workshop:Learn(npc, { name = (type(name) == "string" and not W.IsSecret(name)) and name or "?", map = map, x = x, y = y, items = items }, true)
end

W:On("LOADED", function()
	W.db.vendors = type(W.db.vendors) == "table" and W.db.vendors or {}
	for npc, v in pairs(W.db.vendors) do -- hearsay grows old
		if type(v) ~= "table" or type(v.items) ~= "table" or (not v.mine and time() - (v.at or 0) >= Workshop.HEARD_TTL) then W.db.vendors[npc] = nil end
	end
end)

local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "MERCHANT_SHOW")
f:SetScript("OnEvent", function() pcall(OnMerchant) end)
