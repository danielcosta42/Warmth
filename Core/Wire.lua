--=============================================================================
-- The ChehulCamp wire format, version C2. Pure functions: no state, no client calls.
--
--   C2|A|map|x|y|zuid|tier|n|age|o,o,o|Name~c;Name~c|note   the owner's announce (the only one on the realm bus)
--   C2|J|owner|c|o                                       "I am in <owner>'s circle" (whisper to the owner, guild, group)
--   C2|X                                                 the owner ended the camp
--   C2|I|owner                                           "invite me to your copy of the zone" (whisper to the owner)
--   C2|V|npc|map|x|y|i,i,i|name                          a vendor of camp materials: who, where, which items
--
-- tier: 1..3, then optional flag letters ("2v"): v = the fire burns with violet flames. Unknown letters are
-- ignored, so a flag can be added later without breaking older clients.
-- x, y: 0..10000. zuid: the zone copy, 0 = unknown. n: people in the circle. age: minutes since it was first
-- announced. o: object index (Core/Data.lua).
-- c: class as one letter, 'a' = unknown, 'b' = W.CLASSES[1]... An announce must fit ONE addon message: people
-- are dropped until it does, objects never.
--=============================================================================
local _, W = ...
local Wire = {}
W.Wire = Wire

Wire.MAX       = 240 -- bytes of an announce (one addon message carries 255)
Wire.NOTE_MAX  = 80
Wire.NAME_MAX  = 40
Wire.PEOPLE    = 9   -- people an announce names (the ring draws that many)
Wire.COUNT_MAX = 40
Wire.AGE_MAX   = 1440 -- minutes
Wire.VENDOR_ITEMS = 12 -- items a vendor message names

local function ClassChar(i) return string.char(97 + (tonumber(i) or 0)) end
local function ClassIndex(ch)
	local i = (ch or ""):byte()
	i = i and (i - 97) or 0
	return (i >= 0 and i <= #W.CLASSES) and i or 0
end

-- A name as it may travel and be shown: no separators, no control characters, a sane length.
local function GoodName(name)
	return type(name) == "string" and #name >= 1 and #name <= Wire.NAME_MAX and not name:find("[|;~%c]")
end
Wire.GoodName = GoodName

-- At most `max` bytes, never ending in the middle of a UTF-8 character.
local function Cut(s, max)
	if #s <= max then return s end
	local cut = max
	while cut > 0 and s:byte(cut + 1) >= 128 and s:byte(cut + 1) < 192 do cut = cut - 1 end -- next byte continues a character
	return s:sub(1, cut)
end

function Wire.CleanNote(note)
	return Cut(tostring(note or ""):gsub("[|%c]", " "):gsub("^%s+", ""):gsub("%s+$", ""), Wire.NOTE_MAX)
end

-- fields: map, x, y (0..1), zuid, tier, n, age (minutes), objs = { index }, people = { { name, class } }, note
function Wire.Announce(f)
	local objs = {}
	for i = 1, math.min(#f.objs, W.SLOTS[f.tier]) do objs[i] = f.objs[i] end
	local note = Wire.CleanNote(f.note)
	local head = table.concat({ "C2", "A", f.map, math.floor(f.x * 10000 + 0.5), math.floor(f.y * 10000 + 0.5),
		f.zuid or 0, f.tier .. (f.flame == 1 and "v" or ""), math.min(f.n or 0, Wire.COUNT_MAX), math.min(math.floor(f.age or 0), Wire.AGE_MAX),
		table.concat(objs, ",") }, "|")
	local people, size = {}, #head + 2 + #note
	for i = 1, math.min(#f.people, Wire.PEOPLE) do
		local p = f.people[i]
		local item = p.name .. "~" .. ClassChar(p.class)
		if GoodName(p.name) and size + #item + 1 <= Wire.MAX then
			people[#people + 1] = item
			size = size + #item + 1
		end
	end
	return head .. "|" .. table.concat(people, ";") .. "|" .. note
end

function Wire.Join(owner, class, obj)
	return table.concat({ "C2", "J", owner, ClassChar(class), obj or 0 }, "|")
end
function Wire.End() return "C2|X" end
function Wire.Vendor(npc, v)
	local items = {}
	for i = 1, math.min(#v.items, Wire.VENDOR_ITEMS) do items[i] = v.items[i] end
	return table.concat({ "C2", "V", npc, v.map, math.floor(v.x * 10000 + 0.5), math.floor(v.y * 10000 + 0.5),
		table.concat(items, ","), Cut((tostring(v.name):gsub("[|;~%c]", " ")), Wire.NAME_MAX) }, "|")
end
function Wire.Invite(owner) return "C2|I|" .. owner end

local function Int(s, lo, hi)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 10 then return nil end
	local n = tonumber(s)
	return (n and n >= lo and n <= hi) and n or nil
end

-- A validated message, or nil. Nothing downstream re-checks these fields.
function Wire.Decode(payload)
	if type(payload) ~= "string" or #payload > 255 then return nil end
	local ver, kind, a, b, c, d, e, f, age, g, h, note = strsplit("|", payload, 12)
	if ver ~= "C2" then return nil end
	if kind == "X" then
		return a == nil and { kind = "X" } or nil
	elseif kind == "I" then
		return (GoodName(a) and b == nil) and { kind = "I", owner = a } or nil
	elseif kind == "V" then
		local npc, map, x, y = Int(a, 1, 9999999), Int(b, 1, 99999), Int(c, 0, 10000), Int(d, 0, 10000)
		if not (npc and map and x and y and type(e) == "string" and GoodName(f) and age == nil) then return nil end
		local items, seen = {}, {}
		for item in e:gmatch("[^,]+") do
			local id = Int(item, 1, 9999999)
			if not id or #items >= Wire.VENDOR_ITEMS then return nil end
			if not seen[id] then seen[id] = true; items[#items + 1] = id end
		end
		if #items == 0 then return nil end
		return { kind = "V", npc = npc, map = map, x = x / 10000, y = y / 10000, items = items, name = f }
	elseif kind == "J" then
		local obj = Int(c, 0, #W.OBJECTS)
		if not (GoodName(a) and type(b) == "string" and #b == 1 and obj and d == nil) then return nil end
		return { kind = "J", owner = a, class = ClassIndex(b), obj = obj }
	elseif kind == "A" then
		local map, x, y, zuid = Int(a, 1, 99999), Int(b, 0, 10000), Int(c, 0, 10000), Int(d, 0, 2147483647)
		local digit, flags = tostring(e):match("^(%d)(%l?%l?%l?%l?)$")
		local tier, n = Int(digit, 1, #W.SLOTS), Int(f, 0, Wire.COUNT_MAX)
		age = Int(age, 0, Wire.AGE_MAX)
		if not (map and x and y and zuid and tier and n and age and type(g) == "string" and type(h) == "string" and note) then return nil end
		local objs, seen = {}, {}
		for item in g:gmatch("[^,]+") do
			local o = Int(item, 1, #W.OBJECTS)
			if not o or #objs >= W.SLOTS[tier] then return nil end
			if not seen[o] then seen[o] = true; objs[#objs + 1] = o end
		end
		local people = {}
		for item in h:gmatch("[^;]+") do
			local name, ch = item:match("^(.-)~(%l)$")
			if not GoodName(name) or #people >= Wire.PEOPLE then return nil end
			people[#people + 1] = { name = name, class = ClassIndex(ch) }
		end
		return { kind = "A", map = map, x = x / 10000, y = y / 10000, zuid = zuid, tier = tier, n = n, age = age,
			flame = flags:find("v", 1, true) and 1 or 0,
			objs = objs, people = people, note = Wire.CleanNote(note) }
	end
	return nil
end
