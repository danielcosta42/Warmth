--=============================================================================
-- The Workshop view: every camp object the player's professions make, how far each is from done, and what to do
-- about the selected one (open the profession, or mark the vendor of what is missing).
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Wd, L, C = UI.T, UI.Widgets, W.L, UI.C
local PAD, WIDTH = UI.PAD, UI.W - 2 * UI.PAD
local ROWS, ROW_H = 6, 54

-- The game's waypoint on any place { map, x, y }.
function UI.MarkPlace(place, label)
	local ok = pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(place.map, place.x, place.y)) end)
	pcall(function() C_SuperTrack.SetSuperTrackingUserWaypoint(true) end) -- Forever lacks this call; tried apart
	if ok then W.Print(L["Waypoint set to %s."]:format(label))
	else W.Print(("%s: %s %.1f, %.1f"):format(label, W.Esc(W.ZoneName(place.map)), place.x * 100, place.y * 100)) end
end

local function ZoneNames(places)
	local names = {}
	for i, p in ipairs(places) do names[i] = W.Esc(W.ZoneName(p.map)) end
	return table.concat(names, ", ")
end

local function OpenMap(map)
	pcall(function()
		if WorldMapFrame and not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
		if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(map) end
	end)
end

-- One sentence on how to get an item. `offer(label, fn)` receives the thing to click, when there is one.
function UI.SourceLine(item, offer)
	local name = W.ItemName(item, "#" .. item)
	local s = W.Sources:Get(item)
	if s.kind == "vendor" then
		local where = s.yards and L["%d yd away"]:format(s.yards) or W.Esc(W.ZoneName(s.vendor.map))
		offer(L["Mark %s on the map"]:format(W.Esc(s.vendor.name)), function() UI.MarkPlace(s.vendor, W.Esc(s.vendor.name)) end)
		return (s.heard and L["%s: another player reports it sold by %s (%s)."] or L["%s: sold by %s (%s)."]):format(name, W.Esc(s.vendor.name), where)
	elseif s.kind == "craft" then
		local parts = {}
		for i, from in ipairs(s.from) do parts[i] = (from[2] > 1 and (from[2] .. " ") or "") .. W.ItemName(from[1], "#" .. from[1]) end
		return L["%s: made with %s from %s."]:format(name, L[s.profession], table.concat(parts, ", "))
	elseif s.kind == "nodes" then
		offer(L["Open the map of %s"]:format(W.Esc(W.ZoneName(s.places[1].map))), function() OpenMap(s.places[1].map) end)
		return L["%s: gathered; most nodes in %s."]:format(name, ZoneNames(s.places))
	elseif s.kind == "mobs" then
		local p = s.places[1]
		offer(L["Open the map of %s"]:format(W.Esc(W.ZoneName(p.map))), function() OpenMap(p.map) end)
		return L["%s: dropped by %s (level %d-%d) in %s."]:format(name, W.Esc(p.creature), p.from, p.to, ZoneNames(s.places))
	elseif s.kind == "skin" then
		return L["%s: skinned from beasts around level %d-%d."]:format(name, s.from, s.to)
	elseif s.kind == "cloth" then
		return L["%s: drops from humanoids around level %d-%d."]:format(name, s.from, s.to)
	elseif s.kind == "disenchant" then
		return L["%s: from disenchanting items around level %d-%d."]:format(name, s.from, s.to)
	elseif s.kind == "fish" then
		return (s.from == "start" and L["%s: fished in the fresh waters of the starting zones."] or L["%s: fished in fresh water, in zones around level 30-50."]):format(name)
	end
	return L["%s: where it comes from is not known yet."]:format(name)
end

local function Status(e)
	local have = e.bags > 0 and (C.ok .. L["%d in your bags"]:format(e.bags) .. C.r .. C.mute .. "  ·  " .. C.r) or ""
	if e.state == "ready" then return have .. C.ok .. L["can make %d"]:format(e.can) .. C.r end
	if e.state == "materials" then return have .. C.miss .. L["materials missing"] .. C.r end
	if e.state == "recipe" then return have .. C.miss .. L["recipe not learned"] .. C.r end
	if e.state == "skill" then return have .. C.mute .. L["needs %s %d"]:format(W.Esc(e.profession), e.need) .. C.r end
	return have .. C.mute .. L["open %s once"]:format(W.Esc(e.profession)) .. C.r
end

local function Materials(e)
	local parts = {}
	for _, r in ipairs(e.reagents or {}) do
		parts[#parts + 1] = (r.have >= r.need and C.ok or C.miss) .. W.ItemName(r.item, "#" .. r.item) .. " " .. r.have .. "/" .. r.need .. C.r
	end
	return table.concat(parts, C.mute .. "  ·  " .. C.r)
end

-- What to say and offer about the selected object: text, button label, button action.
local function Advice(e)
	local name = W.ObjectName(e.index)
	local function open()
		if not W.Workshop:Open(e.line) then W.Print(L["Could not open %s from here: open it from your spellbook."]:format(W.Esc(e.profession))) end
	end
	if e.state == "ready" then
		return L["You have everything for %d. Open %s to craft it."]:format(e.can, W.Esc(e.profession)), L["Open %s"]:format(W.Esc(e.profession)), open
	elseif e.state == "unknown" then
		return L["Open %s once so the game says what %s takes."]:format(W.Esc(e.profession), name), L["Open %s"]:format(W.Esc(e.profession)), open
	elseif e.state == "skill" then
		return L["%s needs %s %d; you have %d."]:format(name, W.Esc(e.profession), e.need, e.rank)
	elseif e.state == "recipe" then
		if e.need == 20 then return L["Learn %s from your %s trainer, or from the Camping 101 quest."]:format(name, W.Esc(e.profession)) end
		local where = W.BLUEPRINT[e.index]
		return where and L["%s needs a blueprint, reported to drop from %s."]:format(name, where)
			or L["%s needs a blueprint; where it drops is not known yet."]:format(name)
	end
	-- materials: how to get each missing one (five lines at most), and one thing to click for the first that has it
	local lines, label, action = {}, nil, nil
	local function offer(text, fn)
		if not action then label, action = text, fn end
	end
	for _, r in ipairs(e.reagents) do
		if r.have < r.need and #lines < 5 then
			local text = UI.SourceLine(r.item, offer)
			lines[#lines + 1] = text
			-- one step back: what a bar or a bolt is made of
			local source = W.Sources:Get(r.item)
			if source.kind == "craft" and #lines < 5 then
				local first = source.from[1][1]
				if W.Count(first) < source.from[1][2] then lines[#lines + 1] = C.mute .. "    " .. C.r .. UI.SourceLine(first, offer) end
			end
		end
	end
	return table.concat(lines, "\n"), label, action
end

local function MakeRow(list)
	local r = CreateFrame("Button", nil, list)
	r:SetHeight(ROW_H)
	r.bg = Wd.Fill(r, T.panel, 0.55)
	r.bg:SetPoint("TOPLEFT", 0, -2); r.bg:SetPoint("BOTTOMRIGHT", 0, 2)
	r.sel = Wd.Fill(r, T.ember, 1, "BORDER")
	r.sel:SetPoint("TOPLEFT", 0, -2); r.sel:SetPoint("BOTTOMLEFT", 0, 2)
	r.sel:SetWidth(3)
	r.hl = r:CreateTexture(nil, "HIGHLIGHT")
	r.hl:SetAllPoints(r.bg)
	r.hl:SetColorTexture(T.ember[1], T.ember[2], T.ember[3], 0.10)
	r.slot = Wd.Slot(r, 34)
	r.slot:SetPoint("LEFT", 10, 0)
	r.slot:EnableMouse(false)
	r.title = Wd.Text(r, 13.5, T.text, "title")
	r.title:SetPoint("TOPLEFT", 54, -9)
	r.title:SetWidth(170)
	r.status = Wd.Text(r, 11.5, T.mute)
	r.status:SetPoint("TOPRIGHT", -8, -11)
	r.status:SetJustifyH("RIGHT")
	r.mats = Wd.Text(r, 11.5, T.mute)
	r.mats:SetPoint("TOPLEFT", 54, -31)
	r.mats:SetWidth(WIDTH - 62)
	r:SetScript("OnClick", function(self)
		if self.entry then UI.workSel = self.entry.index; UI:Render() end
	end)
	return r
end

local function FillRow(r, e)
	r.entry = e
	r.slot:SetObject(e.index)
	r.title:SetText(W.ObjectName(e.index))
	r.status:SetText(Status(e))
	local mats = Materials(e)
	r.mats:SetText(mats ~= "" and mats or (C.mute .. L[W.OBJECTS[e.index][3]] .. " " .. W.SKILL[e.index] .. C.r))
	r.sel:SetShown(UI.workSel == e.index)
	r:SetAlpha((e.state == "skill" or e.state == "recipe") and 0.72 or 1)
end

UI.View("workshop", function(v)
	v.list = Wd.ScrollList(v, ROW_H, ROWS, MakeRow, FillRow)
	v.list:SetPoint("TOPLEFT", PAD, -4)
	v.list:SetSize(WIDTH, ROWS * ROW_H)
	v.empty = Wd.Text(v, 13, T.mute)
	v.empty:SetPoint("TOPLEFT", PAD, -30)
	v.empty:SetWidth(WIDTH)
	v.empty:SetWordWrap(true)
	v.empty:SetSpacing(5)
	v.advice = Wd.Text(v, 12.5, T.text)
	v.advice:SetPoint("TOPLEFT", PAD, -(ROWS * ROW_H) - 20)
	v.advice:SetWidth(WIDTH)
	v.advice:SetWordWrap(true)
	v.advice:SetSpacing(4)
	v.act = Wd.Button(v, true)
	v.act:SetPoint("BOTTOMLEFT", PAD, PAD)
	v.act:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end, function(v)
	local entries = W.Workshop:List()
	UI.title:SetText(L["Workshop"])
	UI.sub:SetText(L["What your professions can make for a camp, and what is missing."])
	local selected
	for _, e in ipairs(entries) do
		if e.index == UI.workSel then selected = e end
	end
	selected = selected or entries[1]
	UI.workSel = selected and selected.index or nil
	v.list:Set(entries)
	v.empty:SetText(#entries == 0 and L["The game reports no profession for this character yet. Every profession makes its own camp objects, from skill 20."] or "")
	if not selected then
		v.advice:SetText("")
		v.act:Hide()
		return
	end
	local text, label, action = Advice(selected)
	v.advice:SetText(text)
	v.act:SetShown(action ~= nil)
	if action then
		v.act:Set(label)
		v.act.fn = action
	end
end)

W:On("VENDORS", function() UI:Render() end)
