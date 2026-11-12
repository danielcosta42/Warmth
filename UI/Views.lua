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
	return L["%.1f kyd away"]:format(d / 1000)
end

local function Ago(ts)
	local d = math.max(0, time() - ts)
	if d < 60 then return L["just now"] end
	if d < 3600 then return L["%d min ago"]:format(math.floor(d / 60)) end
	return L["%d h ago"]:format(math.floor(d / 3600))
end

function UI.Waypoint(camp)
	local ok = pcall(function()
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(camp.map, camp.x, camp.y))
		C_SuperTrack.SetSuperTrackingUserWaypoint(true)
	end)
	if ok then W.Print(L["Waypoint set to %s."]:format(UI.CampTitle(camp)))
	else W.Print(("%s: %s %.1f, %.1f"):format(UI.CampTitle(camp), W.Esc(W.ZoneName(camp.map)), camp.x * 100, camp.y * 100)) end
end

-- A camp object in the player's bags that this camp still lacks, if there is room for it.
local function CanBring(camp)
	if #W.Camps:Objects(camp) >= W.SLOTS[camp.tier] then return nil end
	for index, o in ipairs(W.OBJECTS) do
		if W.Count(o[1]) > 0 and not W.Camps:Has(camp, index) then return o[2] end
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
end

UI.View("list", function(v)
	v.chips = {}
	local x = PAD
	for i, flt in ipairs(FILTERS) do
		local b = Wd.Button(v)
		b:SetHeight(24)
		b.label:SetFont(UI.Font(), 11.5, "")
		b.fn = function() UI.filter = flt[1] end
		b:Set(L[flt[2]])
		b:SetWidth(b.label:GetStringWidth() + 22)
		b:SetPoint("TOPLEFT", x, 0)
		x = x + b:GetWidth() + 6
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
	v.build:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	v.build.fn = function() UI:Show("build") end
end, function(v)
	local all, shown, people, match = W.Camps:List(), {}, 0, FILTERS[1][3]
	for i, flt in ipairs(FILTERS) do
		v.chips[i]:Set(L[flt[2]], UI.filter == flt[1])
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
	UI.sub:SetText(("%s  ·  %s  ·  %s  ·  %s"):format(W.Esc(W.ZoneName(camp.map)), L[W.TIERS[camp.tier]], L["lit %s"]:format(Ago(camp.at)), UI.Where(camp)))
	UI.ring:Set(camp, fresh)
	v.note:SetText(camp.note ~= "" and ("\"" .. W.Esc(camp.note) .. "\"") or "")

	local lines = {}
	for i, index in ipairs(objs) do
		if i > 6 then lines[#lines + 1] = C.mute .. L["and %d more"]:format(#objs - 6) .. C.r; break end
		local o = W.OBJECTS[index]
		lines[#lines + 1] = C.ember .. o[2] .. C.r .. C.mute .. "   " .. (o[4] and L[o[4]] or L["A crafting station"]) .. C.r
	end
	lines[#lines + 1] = C.mute .. (slots == #objs and L["Every place is taken."] or L["%d of %d places open."]:format(slots - #objs, slots)) .. C.r
	v.objs:SetText(table.concat(lines, "\n"))

	local bring = CanBring(camp)
	local hint = L["Sit by the fire for a minute to get the camp's benefits for an hour."]
	if other == true then hint = C.copy .. L["This camp is in another copy of the zone: you will not see the fire until you are in the owner's group."] .. C.r
	elseif bring then hint = C.ok .. L["Your %s fits here."]:format(bring) .. C.r .. " " .. hint end
	v.hint:SetText(hint)

	v.go:Set(L["Go there"])
	v.go.fn = function() UI.Waypoint(camp) end
	if camp.owner == W.me then
		v.other:Set(L["End announce"])
		v.other.tip = nil
		v.other.fn = function() W.Net:End() end
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
	v.tierLabel:SetPoint("BOTTOMLEFT", PAD, PAD + 156)
	v.tierLabel:SetText(L["The campfire you lit"])
	v.tiers = {}
	for i, name in ipairs(W.TIERS) do
		local b = Wd.Button(v)
		b:SetHeight(26)
		b:SetWidth((WIDTH - 12) / 3)
		b:SetPoint("BOTTOMLEFT", PAD + (i - 1) * ((WIDTH - 12) / 3 + 6), PAD + 124)
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
	v.foot:SetText(L["Nothing goes to the network until you click announce."])
end, function(v)
	local lit = W.lit and (time() - W.lit.at) < 3600 and W.lit
	UI.title:SetText(L["Set up a camp"])
	UI.sub:SetText(lit and (C.ok .. L["%s campfire lit %s."]:format(L[W.TIERS[lit.tier]], Ago(lit.at)) .. C.r .. " " .. L["Now call the network."])
		or L["Light it with the kit in your bags; here you see what you have and call the network."])

	local rows = { { C.ember .. L["Light it"] .. C.r, "" } }
	for i, kit in ipairs(W.KITS) do
		local n, wood = W.Count(kit), W.Count(W.WOOD[i][1])
		rows[#rows + 1] = { L["%s Campfire Kit"]:format(L[W.TIERS[i]]), n > 0 and (C.ok .. L["%d in your bags"]:format(n) .. C.r)
			or (wood > 0 and (C.mute .. L["craftable: %d %s"]:format(wood, W.WOOD[i][2]) .. C.r) or (C.miss .. L["needs %s"]:format(W.WOOD[i][2]) .. C.r)) }
	end
	rows[#rows + 1] = { C.ember .. L["Your camp objects"] .. C.r, "" }
	local have = 0
	for index, o in ipairs(W.OBJECTS) do
		local n = W.Count(o[1])
		if n > 0 and have < 4 then
			have = have + 1
			rows[#rows + 1] = { o[2] .. C.mute .. "   " .. L[o[3]] .. C.r, index == W.myObject and (C.ok .. L["placed"] .. C.r) or (C.ok .. L["%d in your bags"]:format(n) .. C.r) }
		end
	end
	if have == 0 then rows[#rows + 1] = { C.mute .. L["None in your bags. Each profession crafts its own (from skill 20)."] .. C.r, "" } end
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
	if lit and not UI.tierTouched then UI.tier = lit.tier end
	for i, b in ipairs(v.tiers) do b:Set(L[W.TIERS[i]], UI.tier == i) end
	v.go:Set(W.Camps:Get(W.me) and L["Announce again here"] or L["Announce this camp"])
end)
