--=============================================================================
-- The camps this client knows about. Fed by Core/Net.lua with messages Core/Wire.lua already validated.
--
-- A camp has two sources of people: the roster the owner's last announce named (far viewers have only that) and
-- the people heard directly saying "I am in this circle" (the owner, guildmates, groupmates and this client).
-- The owner's own client keeps only the second and builds its announce from it.
--=============================================================================
local _, W = ...
local Camps = { all = {} }
W.Camps = Camps

Camps.TTL, Camps.PERSON_TTL = 720, 360 -- seconds without news until a camp / a person heard directly is gone
Camps.MAX, Camps.PEOPLE_MAX = 100, 40
Camps.ENDED = 15 -- seconds an owner's late (relayed) announce is ignored after their End

local seq = 0
local ended = {} -- [owner] = GetTime() of their End

function Camps:Get(owner) return self.all[owner or ""] end

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
		camp = { owner = owner, heard = {}, order = {} }
		self.all[owner] = camp
	end
	camp.at = time() - (f.age or 0) * 60 -- when it was first announced, by the owner's count
	camp.map, camp.x, camp.y, camp.zuid, camp.tier = f.map, f.x, f.y, f.zuid or 0, f.tier
	camp.n, camp.objs, camp.roster, camp.note = f.n or 0, f.objs or {}, f.people or {}, f.note or ""
	camp.flame = f.flame or 0
	camp.last = time()
	W:Fire("CAMPS")
	if isNew and owner ~= W.me then W:Fire("CAMP_NEW", camp) end
	return camp, isNew
end

-- `who` said (by an authentic path) that they are in `owner`'s circle.
function Camps:Join(who, owner, class, obj)
	local camp = self.all[owner or ""]
	if not (camp and who) then return false end
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
	by[camp.owner] = by[camp.owner] or { name = camp.owner, class = 0, obj = 0 } -- whoever lit it is there
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
