--=============================================================================
-- The camps this client knows about. Fed by Core/Net.lua with messages Core/Wire.lua already validated.
--
-- A camp has two sources of people: the roster the owner's last announce named (far viewers have only that) and
-- the people heard directly saying "I am in this circle" (the owner, guildmates, groupmates and this client).
-- The owner's own client keeps only the second and builds its announce from it.
--
-- A family camp (camp.family, the flag "l") was lit by a player whose Guild OS, Lodestar or PartyLens announced it
-- for them, without Warmth (the ChehulNet beacon). It is a real camp with a real lighter, but its owner hears none
-- of Warmth's messages: it has no circle, no presence, no invite and no thanks, and nobody is counted in it.
--=============================================================================
local _, W = ...
local Camps = { all = {} }
W.Camps = Camps

Camps.TTL, Camps.PERSON_TTL = 720, 360 -- seconds without news until a camp / a person heard directly is gone
Camps.MAX, Camps.PEOPLE_MAX = 100, 40
Camps.ENDED = 15 -- seconds an owner's late (relayed) announce is ignored after their End
Camps.ENDED_SIGHT = 240 -- and their family beacon's sighting of the same fire (one beat: the beacon stops at its End)

local seq = 0
local ended = {} -- [owner] = GetTime() of their End

function Camps:Get(owner) return self.all[owner or ""] end

-- Yards between two points of one map; nil on different maps or where the client cannot say.
local function Yards(a, b)
	if a.map ~= b.map then return nil end
	if a.x == b.x and a.y == b.y then return 0 end -- the same point needs no map data
	local an, aw = W.World(a.map, a.x, a.y)
	local bn, bw = W.World(b.map, b.x, b.y)
	return an and bn and math.sqrt((an - bn) ^ 2 + (aw - bw) ^ 2) or nil
end

-- A sighting: a fire somebody saw burning and nobody announced. It belongs to no one (its key is the place), so
-- one player crossing a region can leave several; it lives while people keep seeing it. `by`: who saw it last.
-- A known camp at the same place (SAME yards, the same copy of the zone) stands: a lit camp is left alone, a
-- sighting is refreshed. Returns the sighting and whether it is new; nil when it added nothing.
-- SAME is the game's own spacing: no campfire can be placed within 100 yards of a lit one, so two reports closer
-- than that are one fire. The Campfire Nearby aura reaches about as far, and a sighting is where the seer stood,
-- not where the fire is: anything smaller left a trail of pins behind a player crossing one fire's range.
-- f.family: the sighting a family beacon puts on the realm bus for its own player's fire. It is meant to carry no
-- name, so `by` (the relay's claimed origin, which is that player) is not kept; and the camp the same beacon
-- announced on guild or group, if this client heard it, is that fire.
Camps.SAME, Camps.SIGHTS = 100, 40
function Camps:Sight(by, f)
	if f.family then
		local own = self.all[by or ""]
		if own and not own.sight then return nil end -- the lighter's camp, heard on guild or group, is this fire
		if ended[by or ""] and GetTime() - ended[by] < self.ENDED_SIGHT then return nil end -- a beat late, after its End
		by = nil
	end
	local key = ("@%d:%d:%d"):format(f.map, math.floor(f.x * 10000 + 0.5), math.floor(f.y * 10000 + 0.5))
	local known, sights = self.all[key], 0
	for _, camp in pairs(self.all) do
		if camp.sight then sights = sights + 1 end
		local d = not known and not camp.demo and Yards(camp, f)
		if d and d <= self.SAME and ((camp.zuid or 0) == 0 or (f.zuid or 0) == 0 or camp.zuid == f.zuid) then
			if not camp.sight then return nil end -- the lighter's own word stands
			known = camp
		end
	end
	if known then
		known.last, known.by = time(), by or known.by
		known.tier, known.flame = math.max(known.tier, f.tier), f.flame or 0 -- a tier someone read off the fire is kept
		known.family = known.family or f.family
		W:Fire("CAMPS")
		return known, false
	end
	if sights >= self.SIGHTS then return nil end
	local camp = { owner = key, sight = true, spotted = true, by = by, heard = {}, order = {}, at = time(), last = time(),
		map = f.map, x = f.x, y = f.y, zuid = f.zuid or 0, tier = f.tier, flame = f.flame or 0, n = 0, objs = {}, roster = {}, note = "",
		family = f.family }
	self.all[key] = camp
	W:Fire("CAMPS")
	if by ~= W.me then W:Fire("CAMP_NEW", camp) end -- by is nil for a family sighting: news too
	return camp, true
end

-- fields: what Wire.Decode returns for an announce. Returns the camp and whether it is new.
-- `here`: made on this client (my own camp, a demo camp), not heard from the network.
function Camps:Announce(owner, f, here)
	local camp = self.all[owner]
	local isNew = camp == nil
	if isNew then
		if owner ~= W.me and not here then -- the cap and the tombstone are for what comes from the network
			if ended[owner] and GetTime() - ended[owner] < self.ENDED then return nil end
			local n = 0
			for _ in pairs(self.all) do n = n + 1 end
			if n >= self.MAX then return nil end
		end
		for key, sight in pairs(self.all) do -- the lighter announces: a sighting of the same fire has done its part
			if sight.sight and (Yards(sight, f) or math.huge) <= self.SAME then self.all[key] = nil end
		end
		camp = { owner = owner, heard = {}, order = {} }
		self.all[owner] = camp
	end
	camp.at = time() - (f.age or 0) * 60 -- when it was first announced, by the owner's count
	camp.map, camp.x, camp.y, camp.zuid, camp.tier = f.map, f.x, f.y, f.zuid or 0, f.tier
	camp.n, camp.objs, camp.roster, camp.note = f.n or 0, f.objs or {}, f.people or {}, f.note or ""
	camp.flame = f.flame or 0
	camp.spotted = f.spotted or nil
	camp.family = f.family or nil -- Warmth loaded mid-camp on the lighter's client: its own announce clears it
	camp.last = time()
	W:Fire("CAMPS")
	if isNew and owner ~= W.me then W:Fire("CAMP_NEW", camp) end
	return camp, isNew
end

-- `who` said (by an authentic path) that they are in `owner`'s circle.
function Camps:Join(who, owner, class, obj)
	local camp = self.all[owner or ""]
	if not (camp and who) or camp.family then return false end -- an older Warmth may still say so: no circle there
	local h = camp.heard[who]
	if not h then
		local n = 0
		for _ in pairs(camp.heard) do n = n + 1 end
		if n >= self.PEOPLE_MAX then return false end
		h = { obj = 0 }
		camp.heard[who] = h
	end
	if not camp.order[who] then seq = seq + 1; camp.order[who] = seq end
	h.at, h.class = time(), (class and class > 0) and class or h.class or 0
	if obj and obj > 0 then h.obj = obj end
	W:Fire("CAMPS")
	return true
end

function Camps:End(owner)
	ended[owner or ""] = GetTime()
	if not self.all[owner or ""] then return end
	self.all[owner] = nil
	W:Fire("CAMPS")
end

-- { { name, class, obj } }: the owner first, then in the order each was first seen (so the ring stays put).
function Camps:People(camp)
	local cutoff, by = time() - self.PERSON_TTL, {}
	for name, h in pairs(camp.heard) do
		if h.at >= cutoff then by[name] = { name = name, class = h.class or 0, obj = h.obj or 0 } else camp.heard[name] = nil end
	end
	for _, p in ipairs(camp.roster or {}) do
		if not camp.order[p.name] then seq = seq + 1; camp.order[p.name] = seq end -- the owner's order, kept
		if not by[p.name] then by[p.name] = { name = p.name, class = p.class or 0, obj = 0 }
		elseif by[p.name].class == 0 then by[p.name].class = p.class or 0 end
	end
	-- whoever lit it is there; a sighting's key is a place, not a person
	if not camp.sight then by[camp.owner] = by[camp.owner] or { name = camp.owner, class = 0, obj = 0 } end
	local out = {}
	for name, p in pairs(by) do
		if not camp.order[name] then seq = seq + 1; camp.order[name] = seq end
		out[#out + 1] = p
	end
	table.sort(out, function(a, b)
		if (a.name == camp.owner) ~= (b.name == camp.owner) then return a.name == camp.owner end
		return camp.order[a.name] < camp.order[b.name]
	end)
	return out
end

-- Object indexes at the fire: what the announce listed plus what people heard directly placed, within the slots.
function Camps:Objects(camp)
	local out, seen, slots = {}, {}, W.SLOTS[camp.tier]
	local function add(o)
		if o and o > 0 and not seen[o] and #out < slots then seen[o] = true; out[#out + 1] = o end
	end
	for _, o in ipairs(camp.objs or {}) do add(o) end
	for _, p in ipairs(self:People(camp)) do add(p.obj) end
	for i = 1, #W.OBJECTS do -- pieces this player pointed at (Watch:Spot)
		if camp.seen and camp.seen[i] then add(i) end
	end
	return out
end

function Camps:Has(camp, obj)
	for _, o in ipairs(self:Objects(camp)) do
		if o == obj then return true end
	end
	return false
end

-- Violet flames: the owner said so, or this player is standing by the fire and sees them.
function Camps:Violet(camp)
	return camp.flame == 1 or camp.violetSeen == true
end

function Camps:Count(camp)
	if camp.sight then return 0 end -- nobody is known to be at a fire somebody only saw burning
	return math.max(camp.n or 0, #self:People(camp))
end

-- true: another copy of the zone; false: mine; nil: unknown (or another map).
-- camp.notHere: the player stood where the camp is and the game showed no fire there (Core/Watch.lua).
function Camps:OtherCopy(camp)
	if camp.notHere then return true end
	local mine = W.MyCopy(camp.map)
	if mine == 0 or (camp.zuid or 0) == 0 then return nil end
	return camp.zuid ~= mine
end

-- Live camps: my map first (my copy before other copies, then nearest), then the rest by zone name.
function Camps:List()
	local out, cutoff = {}, time() - self.TTL
	for owner, camp in pairs(self.all) do
		if camp.last < cutoff then
			self.all[owner] = nil
		else
			camp.dist, camp.other, camp.zone = W.Distance(camp), self:OtherCopy(camp), W.ZoneName(camp.map)
			out[#out + 1] = camp
		end
	end
	table.sort(out, function(a, b)
		if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
		if a.dist then
			if (a.other == true) ~= (b.other == true) then return b.other == true end
			if a.dist ~= b.dist then return a.dist < b.dist end
		elseif a.zone ~= b.zone then
			return a.zone < b.zone
		end
		return a.owner < b.owner
	end)
	return out
end
