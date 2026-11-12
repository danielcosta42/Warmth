--=============================================================================
-- The compass: a small campfire on the screen that points to the most useful fire nearby. Click it and a ring
-- of camp actions opens around it: light a fire, place a camp object, the sleeping bag, sit, cook, Violet Dust.
--
-- Using an item needs a real click on a secure button, and a secure frame cannot be shown, hidden, moved or
-- re-aimed in combat. So the slices are secure buttons owned by UIParent (never anchored to the compass, which
-- must stay free to drag), they are placed and aimed only outside combat, and the ring closes as combat starts.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Motion, Wd, L = UI.T, UI.Motion, UI.Widgets, W.L
local Compass = { slices = {}, open = false }
UI.Compass = Compass

local SIZE, RADIUS, SLICE, AT_FIRE = 54, 70, 42, 25
local SIT_ICON, COOK_ICON = "Interface\\Icons\\Spell_Nature_Sleep", "Interface\\Icons\\INV_Misc_Food_15"

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- The most useful campfire around: on this map and not in another copy of the zone; one with camp objects
-- (benefits) before an empty one, and among those the nearest.
function Compass.Best()
	local best
	for _, camp in ipairs(W.Camps:List()) do -- this map first, nearest first
		if camp.dist and camp.other ~= true then
			if #W.Camps:Objects(camp) > 0 then return camp end
			best = best or camp
		end
	end
	return best
end

-- How far to turn an arrow that points up so that it points at the camp: radians, counter-clockwise. nil when
-- the game does not say where the player is or which way they face.
function Compass.Bearing(camp)
	local map, x, y = W.Position()
	if not map or map ~= camp.map then return nil end
	local pn, pw = W.World(map, x, y)
	local cn, cw = W.World(camp.map, camp.x, camp.y)
	local facing = GetPlayerFacing and GetPlayerFacing()
	if not (pn and cn and facing) or W.IsSecret(facing) then return nil end
	return math.atan2(cw - pw, cn - pn) - facing -- world: first grows north, second grows west
end

--------------------------------------------------------------------------------
-- The ring's slices
--------------------------------------------------------------------------------
-- What the ring offers right now, in order. kind: "item" (use it), "spell", "macro", or "fn" (plain click).
function Compass.Actions()
	local out = {}
	if W.FireNearby() ~= true then -- no fire here: the best kit in the bags lights one
		for tier = #W.KITS, 1, -1 do
			if W.Count(W.KITS[tier]) > 0 then
				out[#out + 1] = { kind = "item", item = W.KITS[tier], title = L["Light the %s campfire"]:format(L[W.TIERS[tier]]) }
				break
			end
		end
	end
	local objects = 0
	for index, o in ipairs(W.OBJECTS) do
		if objects < 3 and W.Count(o[1]) > 0 then
			objects = objects + 1
			out[#out + 1] = { kind = "item", item = o[1], title = W.ObjectName(index), text = o[4] and L[o[4]] or L["A crafting station"] }
		end
	end
	if W.Count(W.SLEEPING_BAG) > 0 then
		out[#out + 1] = { kind = "item", item = W.SLEEPING_BAG, title = W.ItemName(W.SLEEPING_BAG, "Sleeping Bag"),
			text = L["1% experience a minute lying in it, up to 3%"] }
	end
	out[#out + 1] = { kind = "macro", macro = "/sit", icon = SIT_ICON, title = L["Sit"],
		text = L["A minute resting by a fire that has camp objects gives its benefits."] }
	local cooking = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(W.COOKING_SPELL)) or (GetSpellInfo and GetSpellInfo(W.COOKING_SPELL))
	if type(cooking) == "string" and not W.IsSecret(cooking) then
		out[#out + 1] = { kind = "spell", spell = cooking, icon = COOK_ICON, title = cooking, text = L["Cook at the fire"] }
	end
	if W.db.violetToy then
		-- ponytail: the toy's item id is not public, so it is used by its English name; it shows up here once the
		-- addon has seen the player throw the dust. The toy leaves the game with the launch celebration.
		out[#out + 1] = { kind = "macro", macro = "/use Pouch of Violet Dust", violet = true, title = "Pouch of Violet Dust",
			text = L["Violet flames: the benefits of this fire last two hours instead of one."] }
	end
	out[#out + 1] = { kind = "fn", fn = function() UI:Toggle() end, icon = UI.MEDIA .. "logo", title = "Warmth", text = L["Open the window"] }
	return out
end

local function MakeSlice(i)
	local b = CreateFrame("Button", "WarmthSlice" .. i, UIParent, "SecureActionButtonTemplate")
	-- both: with ActionButtonUseKeyDown on (the default) the secure action fires on the press, otherwise on release
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b:SetSize(SLICE, SLICE)
	b.back = Wd.Tex(b, "disc", T.night, 0.95, "BACKGROUND")
	b.back:SetAllPoints()
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 5, -5)
	b.icon:SetPoint("BOTTOMRIGHT", -5, 5)
	if b.CreateMaskTexture then
		local mask = b:CreateMaskTexture()
		mask:SetTexture(UI.MEDIA .. "disc", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(b.icon)
		b.icon:AddMaskTexture(mask)
	end
	b.ring = Wd.Tex(b, "ring", T.ember, 1, "OVERLAY")
	b.ring:SetAllPoints()
	b.count = Wd.Text(b, 11, T.text, "title")
	b.count:SetPoint("BOTTOMRIGHT", 2, -2)
	b:SetScript("OnEnter", function(self)
		local a = self.action
		if not a then return end
		self.ring:SetVertexColor(1, 0.86, 0.6, 1)
		Wd.Tip(self, a.title, { a.text }, "ANCHOR_RIGHT")
	end)
	b:SetScript("OnLeave", function(self)
		local c = self.action and self.action.violet and T.violet or T.ember
		self.ring:SetVertexColor(c[1], c[2], c[3], 1)
		Wd.HideTip()
	end)
	-- after the secure action: the ring has done its job. Both the press and the release arrive here.
	b:SetScript("PostClick", function(self, _, down)
		if down then return end
		local a = self.action
		if a and a.fn then a.fn() end
		Compass:Close()
	end)
	b:Hide()
	return b
end

local function Aim(b, a)
	b.action = a
	b:SetAttribute("type", a.kind ~= "fn" and a.kind or nil)
	b:SetAttribute("item", a.kind == "item" and ("item:" .. a.item) or nil)
	b:SetAttribute("spell", a.kind == "spell" and a.spell or nil)
	b:SetAttribute("macrotext", a.kind == "macro" and a.macro or nil)
	local icon = a.icon
	if a.kind == "item" then
		local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
		local ok, tex = pcall(f or function() end, a.item)
		icon = (ok and tex) or "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	if a.violet then
		b.icon:SetTexture(UI.MEDIA .. "flame-violet")
		b.icon:SetTexCoord(0, 1 / 8, 0, 1)
	else
		b.icon:SetTexture(icon)
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	local c = a.violet and T.violet or T.ember
	b.ring:SetVertexColor(c[1], c[2], c[3], 1)
	local n = a.kind == "item" and W.Count(a.item) or 0
	b.count:SetText(n > 1 and n or "")
end

function Compass:Open()
	if InCombat() or not self.frame then return false end
	local x, y = self.frame:GetCenter()
	if not x then return false end
	local k = self.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local actions = Compass.Actions()
	for i, a in ipairs(actions) do
		local b = self.slices[i] or MakeSlice(i)
		self.slices[i] = b
		Aim(b, a)
		local angle = math.pi / 2 - (i - 1) / #actions * 2 * math.pi -- the first at twelve o'clock, then clockwise
		b:ClearAllPoints()
		b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k + RADIUS * math.cos(angle), y * k + RADIUS * math.sin(angle))
		b:Show()
		Motion.FadeIn(b, (i - 1) * 0.035)
	end
	for i = #actions + 1, #self.slices do self.slices[i]:Hide() end
	self.open = true
	return true
end

function Compass:Close()
	self.open = false
	if InCombat() then return end -- they left the screen when combat began
	for _, b in ipairs(self.slices) do b:Hide() end
end

--------------------------------------------------------------------------------
-- The compass itself
--------------------------------------------------------------------------------
local function Describe(camp)
	local lines = { L["%d by the fire"]:format(W.Camps:Count(camp)) .. "  ·  " .. L[W.TIERS[camp.tier]] .. "  ·  " .. UI.Where(camp) }
	for _, index in ipairs(W.Camps:Objects(camp)) do
		local o = W.OBJECTS[index]
		lines[#lines + 1] = UI.C.mute .. W.ObjectName(index) .. (o[4] and (": " .. L[o[4]]) or "") .. UI.C.r
	end
	return lines
end

function Compass:Refresh()
	local f = self.frame
	if not f then return end
	local camp = Compass.Best()
	self.best = camp
	f.flame:SetAlpha(camp and 1 or 0.35)
	f.glow.strength = camp and math.min(1, 0.6 + W.Camps:Count(camp) * 0.07) or 0.25
	local violet = camp and W.Camps:Violet(camp) or false
	f.glow:SetViolet(violet)
	f.flame:SetViolet(violet)
	local d = camp and W.Distance(camp)
	f.text:SetText((d and d > AT_FIRE) and L["%d yd"]:format(d) or "")
end

function Compass:Point()
	local f, camp = self.frame, self.best
	local d = camp and W.Distance(camp)
	local turn = (d and d > AT_FIRE) and Compass.Bearing(camp) or nil
	f.pointer:SetShown(turn ~= nil)
	if turn then f.pointer:SetRotation(turn) end
end

function Compass:Build()
	if self.frame then return end
	local f = CreateFrame("Button", "WarmthCompass", UIParent)
	f:SetSize(SIZE, SIZE)
	local at = W.db.compassAt
	f:SetPoint("CENTER", UIParent, "CENTER", at and at[1] or 320, at and at[2] or -160)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.glow = Wd.Glow(f, SIZE * 1.9)
	f.glow:SetPoint("CENTER")
	f.back = Wd.Tex(f, "disc", T.night, 0.9, "BORDER")
	f.back:SetAllPoints()
	f.rim = Wd.Tex(f, "ring", T.ember, 0.9, "ARTWORK")
	f.rim:SetAllPoints()
	f.flame = Wd.Flame(f, SIZE * 0.66)
	f.flame:SetPoint("CENTER", 0, 2)
	f.pointer = Wd.Tex(f, "pointer", T.ember, 1, "OVERLAY")
	f.pointer:SetSize(SIZE + 26, SIZE + 26)
	f.pointer:SetPoint("CENTER")
	f.text = Wd.Text(f, 11, T.mute)
	f.text:SetPoint("TOP", f, "BOTTOM", 0, -2)
	f:SetScript("OnDragStart", function(frame)
		Compass:Close() -- the slices do not follow a drag
		frame:StartMoving()
	end)
	f:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		local x, y = frame:GetCenter()
		local px, py = UIParent:GetCenter()
		if x and px then W.db.compassAt = { x - px, y - py } end
	end)
	f:SetScript("OnClick", function(_, button)
		if button == "RightButton" then UI:Toggle()
		elseif Compass.open then Compass:Close()
		elseif not Compass:Open() then W.Print(L["You are in combat."]) end
	end)
	f:SetScript("OnEnter", function(frame)
		local camp = Compass.best
		local lines = camp and Describe(camp) or { L["No campfire announced near you."] }
		lines[#lines + 1] = UI.C.mute .. L["Click: camp actions.  Right click: Warmth.  Drag to move."] .. UI.C.r
		Wd.Tip(frame, camp and UI.CampTitle(camp) or "Warmth", lines, "ANCHOR_LEFT")
	end)
	f:SetScript("OnLeave", Wd.HideTip)
	local slow, fast = 1, 0
	f:SetScript("OnUpdate", function(_, elapsed)
		slow, fast = slow + elapsed, fast + elapsed
		if slow >= 1 then slow = 0; Compass:Refresh() end
		if fast >= 0.05 then fast = 0; Compass:Point() end
	end)
	self.frame = f
	self:Refresh()
	self:Point()
end

function Compass:Apply()
	if W.db.compass == false then
		self:Close()
		if self.frame then self.frame:Hide() end
	else
		self:Build()
		self.frame:Show()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED") -- fires just before the lockdown: the last moment to hide the ring
events:SetScript("OnEvent", function()
	for _, b in ipairs(Compass.slices) do b:Hide() end
	Compass.open = false
end)
W:On("LOGIN", function() Compass:Apply() end)
W:On("CAMPS", function() Compass:Refresh() end)
