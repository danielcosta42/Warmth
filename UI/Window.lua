--=============================================================================
-- The window: one frame, a header, and three views that trade places with a fade and a slide.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Motion, Wd, L = UI.T, UI.Motion, UI.Widgets, W.L

UI.W, UI.H, UI.PAD = 430, 640, 20
UI.view, UI.sel = "list", nil
UI.views, UI.builders, UI.renderers = {}, {}, {}

-- A view registers how it is built (once) and how it is drawn (every second while shown).
function UI.View(key, build, render)
	UI.builders[key], UI.renderers[key] = build, render
end

function UI:Build()
	if self.frame then return end
	local f = CreateFrame("Frame", "WarmthFrame", UIParent)
	f:SetSize(UI.W, UI.H)
	f:SetPoint("RIGHT", -140, 0)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClipsChildren(true)
	tinsert(UISpecialFrames, "WarmthFrame") -- Escape closes it

	-- Night, paper grain, the warmth coming from where the fire sits, and darker edges.
	Wd.Fill(f, T.night, 0.98):SetAllPoints()
	local grain = Wd.Tex(f, "grain", T.ember, 0.05, "BORDER")
	grain:SetAllPoints()
	grain:SetHorizTile(true)
	grain:SetVertTile(true)
	local warmth = Wd.Tex(f, "glow", T.deep, 0.34, "BORDER")
	warmth:SetSize(760, 760)
	warmth:SetPoint("CENTER", f, "TOP", 0, -250)
	warmth:SetBlendMode("ADD")
	local edges = Wd.Tex(f, "vignette", { 0, 0, 0 }, 0.6, "ARTWORK")
	edges:SetAllPoints()
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
		local t = Wd.Fill(f, T.line, 1, "OVERLAY")
		t:SetPoint(side[1]); t:SetPoint(side[2])
		if side[3] then t:SetWidth(1) else t:SetHeight(1) end
	end
	for _, c in ipairs({ { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 }, { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
		local t = Wd.Tex(f, "corner", T.ember, 0.7, "OVERLAY")
		t:SetSize(26, 26)
		t:SetPoint(c[1], (c[2] == 0) and 5 or -5, (c[4] == 0) and -5 or 5)
		t:SetTexCoord(c[2], c[3], c[4], c[5])
	end

	self.title = Wd.Text(f, 21, T.text, "title")
	self.title:SetPoint("TOPLEFT", UI.PAD, -36)
	self.title:SetWidth(UI.W - 2 * UI.PAD - 20)
	self.sub = Wd.Text(f, 12, T.mute)
	self.sub:SetPoint("TOPLEFT", UI.PAD, -64)
	self.sub:SetWidth(UI.W - 2 * UI.PAD)

	local back = CreateFrame("Button", nil, f)
	back:SetSize(220, 18)
	back:SetPoint("TOPLEFT", UI.PAD, -14)
	back.label = Wd.Text(back, 11.5, T.mute)
	back.label:SetPoint("LEFT")
	back.label:SetText("<  " .. L["Back to the campfires"])
	back:SetScript("OnClick", function() UI:Show("list") end)
	back:SetScript("OnEnter", function() back.label:SetTextColor(T.ember[1], T.ember[2], T.ember[3], 1) end)
	back:SetScript("OnLeave", function() back.label:SetTextColor(T.mute[1], T.mute[2], T.mute[3], 1) end)
	self.back = back

	local close = CreateFrame("Button", nil, f)
	close:SetSize(30, 30)
	close:SetPoint("TOPRIGHT", -8, -6)
	close.x = Wd.Text(close, 18, T.mute)
	close.x:SetPoint("CENTER")
	close.x:SetText("x")
	close:SetScript("OnClick", function() f:Hide() end)
	close:SetScript("OnEnter", function() close.x:SetTextColor(T.ember[1], T.ember[2], T.ember[3], 1) end)
	close:SetScript("OnLeave", function() close.x:SetTextColor(T.mute[1], T.mute[2], T.mute[3], 1) end)

	for key, build in pairs(self.builders) do
		local v = CreateFrame("Frame", nil, f)
		v:SetSize(UI.W, UI.H - 88)
		Motion.Anchor(v, "TOPLEFT", f, "TOPLEFT", 0, -88)
		v:Hide()
		self.views[key] = v
		build(v)
	end

	f:SetScript("OnUpdate", function(_, elapsed)
		UI.acc = (UI.acc or 0) + elapsed
		if UI.acc >= 1 then UI.acc = 0; UI:Render() end
	end)
	f:Hide()
	self.frame = f
end

function UI:Render(fresh)
	if not (self.frame and self.frame:IsShown()) then return end
	self.back:SetShown(self.view ~= "list")
	self.renderers[self.view](self.views[self.view], fresh)
end

-- Shows a view. The new one fades and slides in; a circle opened anew gets everyone arriving in a row.
function UI:Show(view, owner)
	self:Build()
	view = view or self.view
	local changed = view ~= self.view or (owner ~= nil and owner ~= self.sel) or not self.frame:IsShown()
	self.view = view
	if owner then self.sel = owner end
	self.frame:Show()
	for key, v in pairs(self.views) do
		if key == view then
			if changed then Motion.Enter(v, 18) else v:Show() end
		else
			Motion.moving[v] = nil
			v:Hide()
		end
	end
	self:Render(changed)
end

function UI:Toggle()
	self:Build()
	if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

W:On("CAMPS", function() UI:Render() end)
