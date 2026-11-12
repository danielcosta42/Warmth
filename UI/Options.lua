--=============================================================================
-- Warmth in the game's options, under the AddOns tab.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Wd, L = UI.T, UI.Widgets, W.L

local function Flag(key)
	return function() return W.db[key] end, function(v) W.db[key] = v end
end

W:On("LOADED", function()
	local panel = CreateFrame("Frame")
	panel.name = "Warmth"
	local title = Wd.Text(panel, 22, T.ember, "title")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Warmth")
	local sub = Wd.Text(panel, 12, T.mute)
	sub:SetPoint("TOPLEFT", 16, -46)
	sub:SetText(L["Campfires lit by players, on your map."] .. "  v" .. W.VERSION)

	local rows = {
		{ L["Appear in the circle when I stand by an announced campfire"],
			function() return W.db.consent == true end, function(v) W.db.consent = v end },
		{ L["Announce my campfires to the network when I light them"], Flag("auto") },
		{ L["Let visitors ask me for an invite to my camp"], Flag("invites") },
		{ L["Tell the network, later, about vendors of camp materials I open that Warmth does not know"], Flag("shareVendors") },
		{ L["Tell me when a campfire is announced in my zone"], Flag("toast") },
		{ L["Show campfires on the map and the minimap"], Flag("pins") },
		{ L["Show the compass (the small campfire that points to the best fire nearby)"],
			function() return W.db.compass ~= false end, function(v) W.db.compass = v; UI.Compass:Apply() end },
		{ L["Less motion (fades only)"], Flag("lessMotion") },
	}
	panel.checks = {}
	for i, row in ipairs(rows) do
		local c = Wd.Check(panel, row[1], row[2], row[3])
		c:SetPoint("TOPLEFT", 16, -64 - i * 30)
		panel.checks[i] = c
	end
	panel:SetScript("OnShow", function()
		for _, c in ipairs(panel.checks) do c:Refresh() end
	end)
	local note = Wd.Text(panel, 12, T.mute)
	note:SetPoint("TOPLEFT", 16, -64 - (#rows + 1) * 30 - 6)
	note:SetWidth(520)
	note:SetWordWrap(true)
	note:SetText(L["/warmth opens the window. The compass opens the camp actions."])

	UI.options = panel
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Warmth")
		if ok and category then
			pcall(Settings.RegisterAddOnCategory, category)
			UI.optionsCategory = category
		end
	elseif InterfaceOptions_AddCategory then
		pcall(InterfaceOptions_AddCategory, panel)
	end
end)

function UI.OpenOptions()
	local category = UI.optionsCategory
	if category and Settings and Settings.OpenToCategory then
		pcall(Settings.OpenToCategory, (category.GetID and category:GetID()) or category.ID or category)
	else
		W.Print(L["The options are in the game's options, under AddOns."])
	end
end
