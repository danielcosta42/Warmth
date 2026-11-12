--=============================================================================
-- The three views: the lit campfires, one camp's circle, and setting up a camp.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Wd, L, C = UI.T, UI.Widgets, W.L, UI.C
local PAD, WIDTH = UI.PAD, UI.W - 2 * UI.PAD

function UI.CampTitle(camp)
	if camp.owner == W.me then return L["Your camp"] end
	return L["%s's camp"]:format(W.Esc(camp.owner))
end

-- "120 yd away", "1.2 km away" or the zone's name for a camp on another map.
function UI.Where(camp)
	local d = W.Distance(camp)
	if not d then return W.Esc(W.ZoneName(camp.map)) end
	if d < 1000 then return L["%d yd away"]:format(d) end
	return L["%.1fk yd away"]:format(d / 1000)
end

local function Ago(ts)
	local d = math.max(0, time() - ts)
	if d < 60 then return L["just now"] end
	if d < 3600 then return L["%d min ago"]:format(math.floor(d / 60)) end
	return L["%d h ago"]:format(math.floor(d / 3600))
end

function UI.Waypoint(camp)
	local ok = pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(camp.map, camp.x, camp.y)) end)
	-- the arrow that follows the waypoint: Forever does not have this call (measured), so it is tried apart
	pcall(function() C_SuperTrack.SetSuperTrackingUserWaypoint(true) end)
	if ok then W.Print(L["Waypoint set to %s."]:format(UI.CampTitle(camp)))
	else W.Print(("%s: %s %.1f, %.1f"):format(UI.CampTitle(camp), W.Esc(W.ZoneName(camp.map)), camp.x * 100, camp.y * 100)) end
end

-- A camp object in the player's bags that this camp still lacks, if there is room for it.
local function CanBring(camp)
	if #W.Camps:Objects(camp) >= W.SLOTS[camp.tier] then return nil end
	for index, o in ipairs(W.OBJECTS) do
		if W.Count(o[1]) > 0 and not W.Camps:Has(camp, index) then return W.ObjectName(index) end
	end
end

--------------------------------------------------------------------------------
-- Lit campfires
--------------------------------------------------------------------------------
UI.filter = "all"
local FILTERS = {
	{ "all", "All", function() return true end },
	{ "tent", "With a tent", function(c) return W.Camps:Has(c, W.TENT) end },
	{ "repair", "With repairs", function(c) return W.Camps:Has(c, W.REPAIR) end },
	{ "free", "Open place", function(c) return #W.Camps:Objects(c) < W.SLOTS[c.tier] end },
}

local function MakeRow(list)
	local r = CreateFrame("Button", nil, list)
	r:SetHeight(56)
	r.bg = Wd.Fill(r, T.panel, 0.55)
	r.bg:SetPoint("TOPLEFT", 0, -2); r.bg:SetPoint("BOTTOMRIGHT", 0, 2)
	r.hl = r:CreateTexture(nil, "HIGHLIGHT")
	r.hl:SetAllPoints(r.bg)
	r.hl:SetColorTexture(T.ember[1], T.ember[2], T.ember[3], 0.10)
	r.glow = Wd.Glow(r, 60, "BORDER")
	r.glow:SetPoint("LEFT", -4, 0)
	r.flame = Wd.Flame(r, 40)
	r.flame:SetPoint("CENTER", r.glow, "CENTER", 0, 2)
	r.title = Wd.Text(r, 14.5, T.text, "title")
	r.title:SetPoint("TOPLEFT", 58, -11)
	r.title:SetWidth(230)
	r.sub = Wd.Text(r, 11.5, T.mute)
	r.sub:SetPoint("TOPLEFT", 58, -32)
	r.sub:SetWidth(250)
	r.copy = Wd.Tex(r, "copies", T.copy, 1, "OVERLAY")
	r.copy:SetSize(14, 14)
	r.copy:SetPoint("LEFT", r.title, "LEFT", 0, 0)
	r.slots = {}
	for j = 1, 3 do
		local s = Wd.Slot(r, 24)
		s:SetPoint("RIGHT", -8 - (j - 1) * 27, 0)
		s:EnableMouse(false)
		r.slots[j] = s
	end
	r:SetScript("OnClick", function(self) if self.camp then UI:Show("camp", self.camp.owner) end end)
	return r
end

local function FillRow(r, camp)
	local objs = W.Camps:Objects(camp)
	r.camp = camp
	r.copy:SetShown(camp.other == true)
	r.title:ClearAllPoints()
	r.title:SetPoint("TOPLEFT", camp.other == true and 76 or 58, -11)
	r.copy:ClearAllPoints()
	r.copy:SetPoint("TOPLEFT", 58, -12)
	r.title:SetText(UI.CampTitle(camp))
	local where = UI.Where(camp)
	if camp.other == true then where = where .. C.copy .. "  " .. L["another copy"] .. C.r end
	r.sub:SetText(L["%s  ·  %d by the fire  ·  %d of %d"]:format(where, W.Camps:Count(camp), #objs, W.SLOTS[camp.tier]))
	for j, s in ipairs(r.slots) do
		if objs[j] then s:SetObject(objs[j]); s:Show() else s:Hide() end
	end
	r.glow.strength = math.min(1, 0.6 + W.Camps:Count(camp) * 0.06)
	r.glow:SetViolet(W.Camps:Violet(camp))
	r.flame:SetViolet(W.Camps:Violet(camp))
end

UI.View("list", function(v)
	v.chips = {}
	for i, flt in ipairs(FILTERS) do
		local b = Wd.Button(v)
		b:SetHeight(24)
		b.label:SetFont(UI.Font(), 11.5, "")
		b.fn = function() UI.filter = flt[1] end
		b:Set(L[flt[2]])
		v.chips[i] = b
	end
	v.list = Wd.ScrollList(v, 58, 7, MakeRow, FillRow)
	v.list:SetPoint("TOPLEFT", PAD, -36)
	v.list:SetSize(WIDTH, 7 * 58)
	v.empty = Wd.Text(v, 13, T.mute)
	v.empty:SetPoint("TOPLEFT", PAD, -60)
	v.empty:SetWidth(WIDTH)
	v.empty:SetWordWrap(true)
	v.empty:SetSpacing(5)
	v.build = Wd.Button(v, true)
	v.build:SetPoint("BOTTOMLEFT", PAD, PAD)
	v.build:SetWidth(WIDTH * 0.6 - 4)
	v.build.fn = function() UI:Show("build") end
	v.work = Wd.Button(v)
	v.work:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	v.work:SetWidth(WIDTH * 0.4 - 4)
	v.work:Set(L["Workshop"])
	v.work.fn = function() UI:Show("workshop") end
	-- between the list and the buttons: the way to the guestbook, with the player's warmth as a host
	v.book = CreateFrame("Button", nil, v)
	v.book:SetSize(WIDTH, 20)
	v.book:SetPoint("BOTTOM", 0, PAD + 40)
	v.book.label = Wd.Text(v.book, 12, T.mute)
	v.book.label:SetPoint("CENTER")
	v.book:SetScript("OnClick", function() UI:Show("book") end)
	v.book:SetScript("OnEnter", function() v.book.label:SetTextColor(T.ember[1], T.ember[2], T.ember[3], 1) end)
	v.book:SetScript("OnLeave", function() v.book.label:SetTextColor(T.mute[1], T.mute[2], T.mute[3], 1) end)
end, function(v)
	local all, shown, people, match = W.Camps:List(), {}, 0, FILTERS[1][3]
	-- Laid out on every draw: a font string only knows its width once it has been shown, so a width measured
	-- when the window is built comes out too small and the chips overlap.
	local x = PAD
	for i, flt in ipairs(FILTERS) do
		local chip = v.chips[i]
		chip:Set(L[flt[2]], UI.filter == flt[1])
		local w = math.max(chip.label:GetStringWidth() or 0, #L[flt[2]] * 5.5) + 22
		chip:SetWidth(w)
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, 0)
		x = x + w + 6
		if UI.filter == flt[1] then match = flt[3] end
	end
	for _, camp in ipairs(all) do
		people = people + W.Camps:Count(camp)
		if match(camp) then shown[#shown + 1] = camp end
	end
	UI.title:SetText(L["Lit campfires"])
	UI.sub:SetText(#all == 0 and L["No campfire announced on the network right now."]
		or L["%d on the network now, %d people around the fires."]:format(#all, people))
	v.list:Set(shown)
	-- Warmth launches before the rest of the family relays its announces: an empty list is the common case at
	-- first, and it has to read as an invitation, not as a broken addon.
	v.empty:SetText(#shown > 0 and "" or (#all > 0 and L["No campfire matches that filter."] or
		L["Only campfires someone chose to announce show up here, and the network is still young: for now you mostly hear your guild, your group and a few others.\n\nLight a fire, announce it, and be the first warm spot on the map."]))
	v.book.label:SetText(L["Guestbook"] .. "  ·  " .. UI.WarmthLine())
	v.build:Set(W.Camps:Get(W.me) and L["Your camp"] or L["Set up a camp"])
	v.build.fn = function()
		if W.Camps:Get(W.me) then UI:Show("camp", W.me) else UI:Show("build") end
	end
end)

--------------------------------------------------------------------------------
-- A camp
--------------------------------------------------------------------------------
UI.View("camp", function(v)
	UI.ring = UI.BuildRing(v)
	UI.ring:SetPoint("TOP", 0, -4)
	v.note = Wd.Text(v, 14, T.ember, "title")
	v.note:SetPoint("TOP", UI.ring, "BOTTOM", 0, -14)
	v.note:SetWidth(WIDTH)
	v.note:SetJustifyH("CENTER")
	v.objs = Wd.Text(v, 12.5, T.text)
	v.objs:SetPoint("TOPLEFT", PAD, -340)
	v.objs:SetWidth(WIDTH)
	v.objs:SetWordWrap(true)
	v.objs:SetSpacing(5)
	v.hint = Wd.Text(v, 12, T.mute)
	v.hint:SetPoint("BOTTOMLEFT", PAD, PAD + 44)
	v.hint:SetWidth(WIDTH)
	v.hint:SetWordWrap(true)
	v.hint:SetSpacing(3)
	v.go = Wd.Button(v, true)
	v.go:SetPoint("BOTTOMLEFT", PAD, PAD)
	v.go:SetWidth((WIDTH - 8) / 2)
	v.other = Wd.Button(v)
	v.other:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	v.other:SetWidth((WIDTH - 8) / 2)
end, function(v, fresh)
	local camp = W.Camps:Get(UI.sel)
	if not camp then return UI:Show("list") end -- ended or expired while it was open
	local objs, slots = W.Camps:Objects(camp), W.SLOTS[camp.tier]
	local other = W.Camps:OtherCopy(camp)
	UI.title:SetText(UI.CampTitle(camp))
	local host = W.Social.LEVELS[camp.host or 0]
	UI.sub:SetText(("%s  ·  %s  ·  %s  ·  %s"):format(W.Esc(W.ZoneName(camp.map)), L[W.TIERS[camp.tier]], L["lit %s"]:format(Ago(camp.at)), UI.Where(camp))
		.. (host and ("  ·  " .. C.ember .. L["%s host"]:format(L[host]) .. C.r) or ""))
	UI.ring:Set(camp, fresh)
	v.note:SetText(camp.note ~= "" and ("\"" .. W.Esc(camp.note) .. "\"") or "")

	local lines = {}
	for i, index in ipairs(objs) do
		-- four fit above the hint; the ring's slots name the rest on hover
		if i > 4 then lines[#lines + 1] = C.mute .. L["and %d more"]:format(#objs - 4) .. C.r; break end
		local o = W.OBJECTS[index]
		-- a camp buff does not stack with its class equivalent: say so when the player already carries that one
		local have = W.Social:AlreadyHave(index)
		lines[#lines + 1] = C.ember .. W.ObjectName(index) .. C.r .. C.mute .. "   " .. (o[4] and L[o[4]] or L["A crafting station"])
			.. (have and ("  " .. L["(you already have %s)"]:format(have)) or "") .. C.r
	end
	if camp.wants and #camp.wants > 0 then
		local names = {}
		for i, index in ipairs(camp.wants) do
			if i <= 3 then names[i] = W.ObjectName(index) end
		end
		lines[#lines + 1] = C.ember .. L["Asks for: %s"]:format(table.concat(names, ", ")) .. (#camp.wants > 3 and "..." or "") .. C.r
	end
	lines[#lines + 1] = C.mute .. (slots == #objs and L["Every place is taken."] or L["%d of %d places open."]:format(slots - #objs, slots)) .. C.r
	if W.Camps:Violet(camp) then lines[#lines + 1] = UI.Hex(T.violet) .. L["Violet flames: the benefits of this fire last two hours instead of one."] .. C.r end
	v.objs:SetText(table.concat(lines, "\n"))

	local bring = CanBring(camp)
	local hint = L["Sit by the fire for a minute to get the camp's benefits for an hour."]
	if #objs == 0 then
		-- A fire with no camp object gives nothing (guides, and measured: a minute at one ended the Camp Benefits
		-- the player already had). The addon only knows the objects its own users placed, hence "reported".
		hint = L["No camp object reported here: the fire alone gives no benefits. Bring one from your profession."]
		if W.Watch:Near() == camp then hint = hint .. " " .. L["Point at a piece someone else placed and Warmth notes it."] end
		if W.HasAura(W.AURA.BENEFITS) == true then
			hint = hint .. " " .. C.miss .. L["You carry Camp Benefits: resting at a fire with no objects may end them."] .. C.r
		end
	end
	if camp.notHere then hint = C.copy .. L["You are where this camp is and there is no fire: it burns in another copy of the zone, or it went out."] .. C.r
	elseif other == true then hint = C.copy .. L["This camp is in another copy of the zone: you will not see the fire until you are in the owner's group."] .. C.r
	elseif bring then hint = C.ok .. L["Your %s fits here."]:format(bring) .. C.r .. " " .. hint
	elseif not camp.notHere then
		-- nothing in the bags for this camp, but maybe in the player's professions (the Workshop)
		local could = W.Workshop:CouldBring(camp)
		if could and could.state == "ready" then
			hint = C.ok .. L["You can craft a %s for this camp."]:format(W.ObjectName(could.index)) .. C.r .. " " .. hint
		elseif could then
			hint = L["You could craft a %s for this camp; the Workshop says what is missing."]:format(W.ObjectName(could.index)) .. " " .. hint
		end
	end
	v.hint:SetText(hint)

	v.go:Set(L["Go there"])
	v.go.fn = function() UI.Waypoint(camp) end
	if camp.owner == W.me then
		-- at my own fire there is nowhere to go: the main button is whether the camp asks for what it lacks
		v.go:Set(W.db.asking ~= false and L["Asking for objects"] or L["Not asking"])
		v.go.fn = function()
			W.db.asking = W.db.asking == false
			W.Net:Extras()
		end
		v.other:Set(L["End announce"])
		v.other.tip = nil
		v.other.fn = function() W.Net:End() end
	elseif W.Social:CanThank(camp) then
		v.other:Set(L["Thank the host"])
		v.other.tip = L["Warms the host: one thanks a day per host counts toward their level."]
		v.other.fn = function()
			if W.Net:Thank(camp.owner) then W.Print(L["You thanked %s for the fire."]:format(W.Esc(camp.owner))) end
		end
	elseif other == false then
		v.other:Set(L["Back to the list"])
		v.other.tip = nil
		v.other.fn = function() UI:Show("list") end
	else
		v.other:Set(L["Ask for an invite"])
		v.other.tip = L["Asks the owner for a group invite, which puts you in their copy of the zone."]
		v.other.fn = function()
			local ok, why = W.Net:RequestInvite(camp.owner)
			W.Print(ok and L["Asked %s for an invite."]:format(W.Esc(camp.owner)) or L[UI.REASONS[why] or "Could not ask right now."])
		end
	end
end)

UI.REASONS = {
	no_position = "The game gives no position here (an instance?).",
	too_soon = "Wait a few seconds and try again.",
	no_network = "The ChehulNet network did not load.",
	full = "Too many campfires known right now.",
	bad_tier = "Pick the campfire you lit.",
	no_camp = "That camp is gone.",
	no_fire = "There is no campfire near you. Light one first.",
	demo = "This is a demo camp: nobody is there to invite you.",
}

--------------------------------------------------------------------------------
-- Set up a camp
--------------------------------------------------------------------------------
UI.tier = 1
UI.View("build", function(v)
	v.lines = {}
	for i = 1, 13 do
		local l = Wd.Text(v, 12.5, T.text)
		l:SetPoint("TOPLEFT", PAD, -(i - 1) * 22)
		l:SetWidth(WIDTH)
		local r = Wd.Text(v, 12.5, T.mute)
		r:SetPoint("TOPRIGHT", -PAD, -(i - 1) * 22)
		r:SetJustifyH("RIGHT")
		v.lines[i] = { l, r }
	end
	v.tierLabel = Wd.Text(v, 11.5, T.mute)
	v.tierLabel:SetPoint("BOTTOMLEFT", PAD, PAD + 198)
	v.tierLabel:SetText(L["Your campfire"])
	-- Where the Light button sits. The button itself is a secure frame owned by UIParent (UI.SyncLight): anchored
	-- here it would make the whole window protected, and the window could not be moved or closed in combat.
	v.lightSlot = CreateFrame("Frame", nil, v)
	v.lightSlot:SetPoint("BOTTOMLEFT", PAD, PAD + 130)
	v.lightSlot:SetPoint("BOTTOMRIGHT", -PAD, PAD + 130)
	v.lightSlot:SetHeight(30)
	Wd.Fill(v.lightSlot, T.panel, 0.6):SetAllPoints()
	v.lightText = Wd.Text(v.lightSlot, 12, T.mute)
	v.lightText:SetPoint("CENTER")
	v.tiers = {}
	for i, name in ipairs(W.TIERS) do
		local b = Wd.Button(v)
		b:SetHeight(26)
		b:SetWidth((WIDTH - 12) / 3)
		b:SetPoint("BOTTOMLEFT", PAD + (i - 1) * ((WIDTH - 12) / 3 + 6), PAD + 166)
		b.label:SetFont(UI.Font(), 12, "")
		b.fn = function() UI.tier, UI.tierTouched = i, true end
		b:Set(L[name])
		v.tiers[i] = b
	end
	v.inputLabel = Wd.Text(v, 11.5, T.mute)
	v.inputLabel:SetPoint("BOTTOMLEFT", PAD, PAD + 100)
	v.inputLabel:SetText(L["A word for the network (optional)"])
	local input = CreateFrame("EditBox", nil, v)
	input:SetPoint("BOTTOMLEFT", PAD, PAD + 68)
	input:SetPoint("BOTTOMRIGHT", -PAD, PAD + 68)
	input:SetHeight(26)
	input:SetFont(UI.Font(), 13, "")
	input:SetTextColor(T.text[1], T.text[2], T.text[3], 1)
	input:SetTextInsets(8, 8, 0, 0)
	input:SetAutoFocus(false)
	input:SetMaxLetters(W.Wire.NOTE_MAX)
	input:SetScript("OnEscapePressed", input.ClearFocus)
	input:SetScript("OnEnterPressed", input.ClearFocus)
	Wd.Fill(input, T.panel, 0.9):SetAllPoints()
	v.input = input
	v.go = Wd.Button(v, true)
	v.go:SetPoint("BOTTOMLEFT", PAD, PAD + 24)
	v.go:SetPoint("BOTTOMRIGHT", -PAD, PAD + 24)
	v.go.fn = function()
		local camp, why = W.Net:Announce(UI.tier, input:GetText())
		if not camp then return W.Print(L[UI.REASONS[why] or "Could not announce right now."]) end
		input:ClearFocus()
		UI:Show("camp", W.me)
	end
	v.foot = Wd.Text(v, 11.5, T.mute)
	v.foot:SetPoint("BOTTOMLEFT", PAD, PAD)
	v.foot:SetText(L["Your campfire is not announced until you click."])
end, function(v)
	local lit = W.lit and (time() - W.lit.at) < 3600 and W.lit
	UI.title:SetText(L["Set up a camp"])
	local burn = lit and W.db.burn and W.db.burn[lit.tier]
	local left = burn and math.floor((burn - (time() - lit.at)) / 60)
	UI.sub:SetText(lit and (C.ok .. L["%s campfire lit %s."]:format(L[W.TIERS[lit.tier]], Ago(lit.at)) .. C.r .. " "
			.. ((left and left > 0) and L["About %d min of fire left."]:format(left) or L["Now call the network."]))
		or L["Light it with the kit in your bags; here you see what you have and call the network."])

	local rows = { { C.ember .. L["Light it"] .. C.r, "" } }
	for i, kit in ipairs(W.KITS) do
		local n, wood = W.Count(kit), W.Count(W.WOOD[i][1])
		local woodName = W.ItemName(W.WOOD[i][1], W.WOOD[i][2])
		rows[#rows + 1] = { W.ItemName(kit, L["%s Campfire Kit"]:format(L[W.TIERS[i]])), n > 0 and (C.ok .. L["%d in your bags"]:format(n) .. C.r)
			or (wood > 0 and (C.mute .. L["craftable: %d %s"]:format(wood, woodName) .. C.r) or (C.miss .. L["needs %s"]:format(woodName) .. C.r)) }
	end
	rows[#rows + 1] = { C.ember .. L["Your camp objects"] .. C.r, "" }
	local have = 0
	for index, o in ipairs(W.OBJECTS) do
		local n = W.Count(o[1])
		if n > 0 and have < 4 then
			have = have + 1
			rows[#rows + 1] = { W.ObjectName(index) .. C.mute .. "   " .. L[o[3]] .. C.r, C.ok .. L["%d in your bags"]:format(n) .. C.r }
		end
	end
	if have == 0 then rows[#rows + 1] = { C.mute .. L["None in your bags. Each profession crafts its own (from skill 20)."] .. C.r, "" } end
	if W.Count(W.SLEEPING_BAG) > 0 then
		rows[#rows + 1] = { W.ItemName(W.SLEEPING_BAG, "Sleeping Bag") .. C.mute .. "   " .. L["1% experience a minute lying in it, up to 3%"] .. C.r, C.ok .. L["in your bags"] .. C.r }
	end
	rows[#rows + 1] = { C.ember .. L["Cook at the fire"] .. C.r, "" }
	if W.cooking then
		rows[#rows + 1] = { W.cooking.ready > 0 and W.Esc(table.concat(W.cooking.names, ", ")) or L["Nothing with what you carry."],
			W.cooking.ready > 0 and (C.ok .. L["%d recipes ready"]:format(W.cooking.ready) .. C.r) or "" }
	else
		rows[#rows + 1] = { C.mute .. L["Open your Cooking window once to see what you can make."] .. C.r, "" }
	end
	for i, pair in ipairs(v.lines) do
		pair[1]:SetText(rows[i] and rows[i][1] or "")
		pair[2]:SetText(rows[i] and rows[i][2] or "")
	end
	-- What the lower half asks for depends on what the game says about the fire:
	--   light   no campfire near: offer the kits in the bags (a choice only when there is more than one tier)
	--   lit     a campfire near and it is the one this player lit: its tier is known, nothing to choose
	--   which   a campfire near that the addon did not see lit (a /reload long ago): ask which it is
	--   manual  the client cannot say whether a fire is near: everything, as a fallback
	local fire, mine = W.FireNearby(), W.Watch:MyFire()
	local mode = (fire == nil and "manual") or (fire == false and "light") or (mine and "lit") or "which"
	local owned = {}
	for i, kit in ipairs(W.KITS) do
		if W.Count(kit) > 0 then owned[#owned + 1] = i end
	end
	if mode == "lit" then
		UI.tier = mine.tier
	elseif mode == "light" and W.Count(W.KITS[UI.tier]) == 0 and #owned > 0 then
		UI.tier = owned[#owned] -- the best kit in the bags
	elseif lit and not UI.tierTouched then
		UI.tier = lit.tier
	end
	local choose = mode == "which" or mode == "manual" or (mode == "light" and #owned > 1)
	for i, b in ipairs(v.tiers) do
		b:Set(L[W.TIERS[i]], UI.tier == i)
		b:SetShown(choose and (mode ~= "light" or W.Count(W.KITS[i]) > 0))
	end
	v.tierLabel:SetText((mode == "lit" and L["%s campfire: %d places for camp objects"]:format(L[W.TIERS[UI.tier]], W.SLOTS[UI.tier]))
		or (mode == "which" and L["Which campfire is this?"])
		or (mode == "light" and (#owned > 1 and L["Which kit to light"] or ""))
		or L["Your campfire"])
	UI.canLight = mode == "light" or mode == "manual"
	v.lightSlot:SetShown(UI.canLight)
	v.go:Set((mode == "light" and L["Light a campfire first"]) or (W.Camps:Get(W.me) and L["Announce again here"] or L["Announce this camp"]),
		nil, mode == "light")
	v.foot:SetText(W.db.auto ~= false and L["The campfires you light are announced to the network by themselves (see the options)."]
		or L["Your campfire is not announced until you click."])
	UI.SyncLight()
	local lighting = UI.light and UI.light:IsShown()
	v.lightText:SetText(lighting and "" or ((InCombatLockdown and InCombatLockdown()) and L["You are in combat."]
		or (#owned == 0 and L["No campfire kit in your bags."])
		or L["No %s kit in your bags."]:format(L[W.TIERS[UI.tier]])))
end)

--------------------------------------------------------------------------------
-- Light: one click uses the campfire kit from the bags. Using an item needs a secure button and a real click;
-- a secure frame cannot be shown, hidden, moved or re-aimed in combat, so all of that happens only outside it,
-- and the button leaves the screen as combat starts.
--------------------------------------------------------------------------------
local function MakeLight()
	local b = CreateFrame("Button", "WarmthLightButton", UIParent, "SecureActionButtonTemplate")
	-- both: with ActionButtonUseKeyDown on (the default) the secure action fires on the press, otherwise on release
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetAttribute("type", "item")
	-- one strata above the window (DIALOG, raised on every Show): on the same strata the window covered it
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b.bg = Wd.Fill(b, T.ember)
	b.bg:SetAllPoints()
	b.label = Wd.Text(b, 13, T.night, "title")
	b.label:SetPoint("CENTER")
	b:SetScript("OnEnter", function() b.bg:SetColorTexture(1, 0.78, 0.42, 1) end)
	b:SetScript("OnLeave", function() b.bg:SetColorTexture(T.ember[1], T.ember[2], T.ember[3], 1) end)
	b:Hide()
	UI.light = b
	return b
end

function UI.SyncLight()
	if InCombatLockdown and InCombatLockdown() then return end
	local kit = W.KITS[UI.tier]
	local slot = UI.views.build and UI.views.build.lightSlot
	-- UI.frame is still nil while the window is being built (its first Hide runs OnHide, which calls this)
	local want = slot and UI.frame and UI.frame:IsShown() and UI.view == "build" and UI.canLight and W.Count(kit) > 0
	local b = UI.light
	if not want then
		if b and b:IsShown() then b:Hide() end
		return
	end
	b = b or MakeLight()
	local x, y = slot:GetCenter()
	if not x then return end
	local k = slot:GetEffectiveScale() / UIParent:GetEffectiveScale()
	b:SetSize(slot:GetWidth() * k, slot:GetHeight() * k)
	b:ClearAllPoints()
	b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k, y * k)
	if b.item ~= kit then
		b:SetAttribute("item", "item:" .. kit)
		b.item = kit
	end
	b.label:SetText(L["Light the %s campfire"]:format(L[W.TIERS[UI.tier]]))
	b:Show()
end

local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED") -- fires just before the lockdown: the last moment to hide it
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if UI.light then UI.light:Hide() end
	elseif UI.frame then
		UI.SyncLight()
	end
end)

--------------------------------------------------------------------------------
-- The guestbook: the camps this player sat at, and their warmth as a host
--------------------------------------------------------------------------------
-- "warmth 7, Ember host (3 more for Hearth)"
function UI.WarmthLine()
	local S = W.Social
	local points, level = W.db.heat.points, W.Social:MyLevel()
	local text = L["warmth %d"]:format(points)
	if level > 0 then text = text .. ", " .. L["%s host"]:format(L[S.LEVELS[level]]) end
	local nextStep = S.STEPS[level + 1]
	if nextStep then text = text .. " (" .. L["%d more for %s"]:format(nextStep - points, L[S.LEVELS[level + 1]]) .. ")" end
	return text
end

UI.View("book", function(v)
	v.list = Wd.ScrollList(v, 46, 9, function(list)
		local r = CreateFrame("Frame", nil, list)
		r:SetHeight(46)
		r.bg = Wd.Fill(r, T.panel, 0.45)
		r.bg:SetPoint("TOPLEFT", 0, -2); r.bg:SetPoint("BOTTOMRIGHT", 0, 2)
		r.title = Wd.Text(r, 13.5, T.text, "title")
		r.title:SetPoint("TOPLEFT", 12, -7)
		r.sub = Wd.Text(r, 11.5, T.mute)
		r.sub:SetPoint("TOPLEFT", 12, -26)
		return r
	end, function(r, visit)
		r.title:SetText(L["%s's camp"]:format(W.Esc(visit.owner)))
		r.sub:SetText(("%s  ·  %s  ·  %s"):format(W.Esc(W.ZoneName(visit.map)), date("%d/%m %H:%M", visit.at), L["%d by the fire"]:format(visit.n)))
	end)
	v.list:SetPoint("TOPLEFT", PAD, -4)
	v.list:SetSize(WIDTH, 9 * 46)
	v.empty = Wd.Text(v, 13, T.mute)
	v.empty:SetPoint("TOPLEFT", PAD, -30)
	v.empty:SetWidth(WIDTH)
	v.empty:SetWordWrap(true)
	v.empty:SetSpacing(5)
	v.foot = Wd.Text(v, 12, T.mute)
	v.foot:SetPoint("BOTTOMLEFT", PAD, PAD)
	v.foot:SetWidth(WIDTH)
	v.foot:SetWordWrap(true)
	v.foot:SetSpacing(4)
end, function(v)
	UI.title:SetText(L["Guestbook"])
	UI.sub:SetText(L["The camps you sat at. As a host: %s."]:format(UI.WarmthLine()))
	v.list:Set(W.db.guestbook)
	v.empty:SetText(#W.db.guestbook == 0 and L["No camp yet. Sit by an announced campfire and it is written here."] or "")
	v.foot:SetText(L["Visitors who sit at your fire can thank you; each person counts once a day toward your warmth."])
end)
