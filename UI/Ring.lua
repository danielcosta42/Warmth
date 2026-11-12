--=============================================================================
-- The circle: the fire in the middle, the camp's object slots around it, the people outside, each one arriving.
-- An empty seat marked "you" is the invitation.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Motion, Wd, L = UI.T, UI.Motion, UI.Widgets, W.L

local SIZE, SEATS, SEAT_R = 290, 9, 124

local function Around(i, n, radius)
	local a = math.pi / 2 - (i - 1) / n * 2 * math.pi
	return radius * math.cos(a), radius * math.sin(a)
end

function UI.BuildRing(parent)
	local ring = CreateFrame("Frame", nil, parent)
	ring:SetSize(SIZE, SIZE)
	ring.glow = Wd.Glow(ring, 250)
	ring.glow:SetPoint("CENTER")
	ring.flame = Wd.Flame(ring, 104)
	ring.flame:SetPoint("CENTER", 0, 6)
	ring.seats, ring.slots, ring.seen = {}, {}, {}
	for i = 1, SEATS + 1 do ring.seats[i] = Wd.Seat(ring, 46) end
	for i = 1, 10 do ring.slots[i] = Wd.Slot(ring, 34) end
	ring.more = Wd.Text(ring, 12, T.mute)
	ring.more:SetPoint("TOP", ring, "BOTTOM", 0, 6)

	-- `fresh`: the circle was just opened, so everyone arrives in a row; afterwards only newcomers do.
	function ring:Set(camp, fresh)
		if fresh then self.seen = {} end
		local people = W.Camps:People(camp)
		local shown, inRing = math.min(#people, SEATS), false
		for _, p in ipairs(people) do
			if p.name == W.me then inRing = true end
		end
		local total = shown + (inRing and 0 or 1)
		for i, seat in ipairs(self.seats) do
			local p = people[i]
			if i <= shown then
				local obj = W.OBJECTS[p.obj or 0]
				seat:SetPerson(p, p.name == camp.owner)
				seat.tipTitle = W.Esc(p.name)
				seat.tipLines = { p.name == camp.owner and L["Lit this fire"] or nil }
				if obj then table.insert(seat.tipLines, L["Brought:"] .. " " .. obj[2]) end
				seat:Show()
				Motion.Place(seat, self, Around(i, total, SEAT_R))
				if not self.seen[p.name] then
					self.seen[p.name] = true
					Motion.Arrive(seat, fresh and (0.2 + (i - 1) * 0.14) or 0)
				elseif not Motion.arriving[seat] then
					seat:SetAlpha(1)
				end
			elseif i == shown + 1 and not inRing then
				seat:SetEmpty(L["you"])
				seat.tipTitle, seat.tipLines = L["A seat by the fire"], { L["Walk up to the fire to join the circle."] }
				Motion.Settle(seat)
				Motion.Place(seat, self, Around(i, total, SEAT_R))
				seat:Show()
			else
				seat:Hide()
			end
		end
		local count = W.Camps:Count(camp)
		self.more:SetText(count > shown and L["and %d more around the fire"]:format(count - shown) or "")
		self.glow.strength = math.min(1, 0.7 + count * 0.05)

		local objs, slots = W.Camps:Objects(camp), W.SLOTS[camp.tier]
		local size, radius = slots > 5 and 26 or 34, slots > 5 and 80 or 76
		for i, slot in ipairs(self.slots) do
			if i <= slots then
				slot:SetSize(size, size)
				local index = objs[i]
				if index then
					local o = W.OBJECTS[index]
					slot:SetObject(index)
					slot.tipTitle, slot.tipLines = o[2], { o[4] and L[o[4]] or L["A crafting station"], UI.C.mute .. L[o[3]] .. UI.C.r }
					slot:Show()
					Motion.Place(slot, self, Around(i + 0.5, slots, radius))
					if not self.seen["o" .. index] then
						self.seen["o" .. index] = true
						Motion.Arrive(slot, fresh and (0.1 + i * 0.07) or 0)
					elseif not Motion.arriving[slot] then
						slot:SetAlpha(1)
					end
				else
					slot:SetEmpty()
					slot.tipTitle, slot.tipLines = L["An open place"], { L["Each player can add one object from their profession."] }
					Motion.Settle(slot)
					Motion.Place(slot, self, Around(i + 0.5, slots, radius))
					slot:Show()
				end
			else
				slot:Hide()
			end
		end
	end
	return ring
end
