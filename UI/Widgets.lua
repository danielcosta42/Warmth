--=============================================================================
-- The pieces the screens are made of.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Motion = UI.T, UI.Motion
local Wd = {}
UI.Widgets = Wd

function Wd.Fill(frame, c, a, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(c[1], c[2], c[3], a or 1)
	return t
end

-- A texture from Media/, tinted.
function Wd.Tex(parent, name, c, a, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(UI.MEDIA .. name)
	if c then t:SetVertexColor(c[1], c[2], c[3], a or 1) end
	return t
end

function Wd.Text(parent, size, c, kind)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(UI.Font(kind), size, "")
	fs:SetTextColor(c[1], c[2], c[3], 1)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

function Wd.Tip(owner, title, lines, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
	GameTooltip:SetText(title, T.ember[1], T.ember[2], T.ember[3], 1, true)
	for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, T.text[1], T.text[2], T.text[3], true) end
	GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end
Wd.HideTip = HideTip

-- A flat button. `primary`: the one action of the view. b.on: a selected chip.
function Wd.Button(parent, primary)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(32)
	b.bg = Wd.Fill(b, T.raised)
	b.bg:SetAllPoints()
	b.label = Wd.Text(b, 13, T.text, "title")
	b.label:SetPoint("CENTER")
	b.primary = primary
	function b:Paint(hover)
		local c, tc = T.raised, T.text
		if self.primary then c, tc = T.ember, T.night
		elseif self.on then c, tc = { T.ember[1] * 0.3, T.ember[2] * 0.3, T.ember[3] * 0.3 }, T.ember end
		local k = hover and 1.15 or 1
		self.bg:SetColorTexture(math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), self.disabled and 0.4 or 1)
		self.label:SetTextColor(tc[1], tc[2], tc[3], self.disabled and 0.5 or 1)
	end
	function b:Set(label, on, disabled)
		self.on, self.disabled = on, disabled
		self.label:SetText(label)
		self:Paint(false)
	end
	b:SetScript("OnEnter", function(self)
		self:Paint(true)
		if self.tip then Wd.Tip(self, self.label:GetText(), { self.tip }) end
	end)
	b:SetScript("OnLeave", function(self) self:Paint(false); HideTip() end)
	b:SetScript("OnClick", function(self)
		if self.fn and not self.disabled then self.fn(); UI:Render() end
	end)
	b:Paint(false)
	return b
end

-- A tick box with a label, for the options.
function Wd.Check(parent, label, get, set)
	local c = CreateFrame("Button", nil, parent)
	c:SetSize(420, 24)
	c.box = Wd.Tex(c, "slot-ring", T.line, 1)
	c.box:SetSize(18, 18)
	c.box:SetPoint("LEFT")
	c.mark = Wd.Tex(c, "slot", T.ember, 1, "OVERLAY")
	c.mark:SetSize(10, 10)
	c.mark:SetPoint("CENTER", c.box, "CENTER")
	c.label = Wd.Text(c, 13, T.text)
	c.label:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
	c.label:SetText(label)
	function c:Refresh() self.mark:SetShown(get() and true or false) end
	c:SetScript("OnClick", function(self) set(not get()); self:Refresh() end)
	c:Refresh()
	return c
end

-- Firelight: a soft disc added to whatever is behind it, breathing.
function Wd.Glow(parent, size, layer)
	local g = CreateFrame("Frame", nil, parent)
	g:SetSize(size, size)
	g.tex = Wd.Tex(g, "glow", T.deep, 1, layer or "BACKGROUND")
	g.tex:SetAllPoints()
	g.tex:SetBlendMode("ADD")
	g.strength = 1
	Motion.Breathe(g, 1.9, function(s) g:SetAlpha(g.strength * (0.72 + 0.28 * s)) end)
	function g:SetViolet(on)
		local c = on and T.violet or T.deep
		self.tex:SetVertexColor(c[1], c[2], c[3], 1)
	end
	return g
end

-- The campfire: an 8-frame sheet stepped by the motion driver.
function Wd.Flame(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetTexture(UI.MEDIA .. "flame")
	f.tex:SetAllPoints()
	Motion.Flipbook(f.tex, 8, 9)
	function f:SetViolet(on)
		if (self.violet or false) == (on or false) then return end
		self.violet = on or false
		self.tex:SetTexture(UI.MEDIA .. (on and "flame-violet" or "flame"))
	end
	return f
end

-- The first letter of the first two words, as whole UTF-8 characters ("Ávila Íris" is two letters, not two bytes).
local LETTER = "[%z\1-\127\194-\244][\128-\191]*"
local function Initials(name)
	local first, rest = tostring(name):match("^(" .. LETTER .. ")%S*%s*(.*)$")
	local second = rest and rest:match("^" .. LETTER) or ""
	local out = (first or "?") .. second
	return out:find("[\128-\255]") and out or out:upper()
end

-- A person by the fire: a ring in the class colour around the game's class portrait (initials when the class is
-- unknown), and a small flame on whoever lit the camp.
function Wd.Seat(parent, size)
	local s = CreateFrame("Frame", nil, parent)
	s:SetSize(size, size)
	s.back = Wd.Tex(s, "disc", T.panel, 1, "BACKGROUND")
	s.back:SetAllPoints()
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetTexture(UI.CLASS_CIRCLES)
	s.icon:SetPoint("TOPLEFT", 4, -4)
	s.icon:SetPoint("BOTTOMRIGHT", -4, 4)
	s.ring = Wd.Tex(s, "ring", T.mute, 1, "OVERLAY")
	s.ring:SetAllPoints()
	s.label = Wd.Text(s, size * 0.3, T.text, "title")
	s.label:SetPoint("CENTER")
	s.crown = Wd.Tex(s, "crown", T.ember, 1, "OVERLAY")
	s.crown:SetSize(size * 0.42, size * 0.42)
	s.crown:SetPoint("CENTER", s, "TOP", 0, -1)
	s:EnableMouse(true)
	s:SetScript("OnEnter", function(self) if self.tipTitle then Wd.Tip(self, self.tipTitle, self.tipLines) end end)
	s:SetScript("OnLeave", HideTip)

	function s:SetPerson(person, isOwner)
		local c = UI.ClassColor(person.class)
		local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[W.CLASSES[person.class or 0] or ""]
		self.ring:SetVertexColor(c[1], c[2], c[3], 1)
		self.back:SetVertexColor(T.panel[1], T.panel[2], T.panel[3], 1)
		if coords then
			self.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
			self.icon:Show()
			self.label:SetText("")
		else
			self.icon:Hide()
			self.label:SetText(Initials(person.name))
			self.label:SetTextColor(c[1], c[2], c[3], 1)
		end
		self.crown:SetShown(isOwner and true or false)
	end
	function s:SetEmpty(label)
		self.ring:SetVertexColor(T.line[1], T.line[2], T.line[3], 1)
		self.back:SetVertexColor(T.night[1], T.night[2], T.night[3], 0.6)
		self.icon:Hide()
		self.crown:Hide()
		self.label:SetText(label)
		self.label:SetTextColor(T.mute[1], T.mute[2], T.mute[3], 1)
	end
	return s
end

-- A place for a camp object: the object's icon in a lit frame, or a dashed empty place.
function Wd.Slot(parent, size)
	local o = CreateFrame("Frame", nil, parent)
	o:SetSize(size, size)
	o.back = Wd.Tex(o, "slot", T.raised, 1, "BACKGROUND")
	o.back:SetAllPoints()
	o.icon = o:CreateTexture(nil, "ARTWORK")
	o.icon:SetPoint("TOPLEFT", 4, -4)
	o.icon:SetPoint("BOTTOMRIGHT", -4, 4)
	o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if o.CreateMaskTexture then -- round the icon's corners to the slot's shape
		local mask = o:CreateMaskTexture()
		mask:SetTexture(UI.MEDIA .. "slot", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(o.icon)
		o.icon:AddMaskTexture(mask)
	end
	o.frame = Wd.Tex(o, "slot-ring", T.ember, 1, "OVERLAY")
	o.frame:SetAllPoints()
	o.dash = Wd.Tex(o, "slot-dash", T.line, 1, "OVERLAY")
	o.dash:SetAllPoints()
	o:EnableMouse(true)
	o:SetScript("OnEnter", function(self) if self.tipTitle then Wd.Tip(self, self.tipTitle, self.tipLines) end end)
	o:SetScript("OnLeave", HideTip)

	function o:SetObject(index)
		local item = W.OBJECTS[index]
		local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
		local ok, icon = pcall(f or function() end, item[1])
		self.icon:SetTexture((ok and icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
		self.icon:Show(); self.frame:Show(); self.dash:Hide()
		self.back:SetVertexColor(T.raised[1], T.raised[2], T.raised[3], 1)
	end
	function o:SetEmpty()
		self.icon:Hide(); self.frame:Hide(); self.dash:Show()
		self.back:SetVertexColor(T.night[1], T.night[2], T.night[3], 0.5)
	end
	return o
end

-- A list that scrolls with the wheel: `visible` rows made by make(parent, i), filled by fill(row, item).
function Wd.ScrollList(parent, rowHeight, visible, make, fill)
	local list = CreateFrame("Frame", nil, parent)
	list.rows, list.items, list.offset = {}, {}, 0
	for i = 1, visible do
		local row = make(list, i)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
		row:SetPoint("RIGHT")
		list.rows[i] = row
	end
	list.thumb = Wd.Fill(list, T.line, 0.9, "OVERLAY")
	list.thumb:SetWidth(3)
	function list:Set(items)
		self.items = items
		self.offset = math.max(0, math.min(self.offset, #items - visible))
		for i, row in ipairs(self.rows) do
			local item = items[i + self.offset]
			if item then fill(row, item); row:Show() else row:Hide() end
		end
		local over = #items > visible
		self.thumb:SetShown(over)
		if over then
			local track = visible * rowHeight
			self.thumb:SetHeight(track * visible / #items)
			self.thumb:ClearAllPoints()
			self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 6, -track * self.offset / #items)
		end
	end
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta)
		self.offset = math.max(0, math.min(self.offset - delta, math.max(0, #self.items - visible)))
		self:Set(self.items)
	end)
	return list
end
