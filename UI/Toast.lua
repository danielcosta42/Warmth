--=============================================================================
-- Things that come to the player: the proximity toast, and the two questions (appear in circles? invite them?).
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Motion, Wd, L = UI.T, UI.Motion, UI.Widgets, W.L

local function Card(width, height, y)
	local f = CreateFrame("Button", nil, UIParent)
	f:SetSize(width, height)
	f:SetFrameStrata("DIALOG")
	Motion.Anchor(f, "TOP", UIParent, "TOP", 0, y)
	Wd.Fill(f, T.panel, 0.96):SetAllPoints()
	local edge = Wd.Fill(f, T.ember, 1, "ARTWORK")
	edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(3)
	f.glow = Wd.Glow(f, 64, "BORDER")
	f.glow:SetPoint("TOPLEFT", 2, 2)
	f.flame = Wd.Flame(f, 40)
	f.flame:SetPoint("CENTER", f.glow, "CENTER", 0, 2)
	f.title = Wd.Text(f, 14.5, T.text, "title")
	f.title:SetPoint("TOPLEFT", 66, -12)
	f.title:SetWidth(width - 78)
	f.line = Wd.Text(f, 12, T.mute)
	f.line:SetPoint("TOPLEFT", 66, -33)
	f.line:SetWidth(width - 78)
	f:Hide()
	return f
end

--------------------------------------------------------------------------------
-- Someone announced a campfire on the map where the player is.
--------------------------------------------------------------------------------
local token = 0
function UI:Toast(camp)
	local t = self.toast
	if not t then
		t = Card(340, 60, -150)
		t:SetScript("OnClick", function(self)
			self:Hide()
			if self.camp then UI:Show("camp", self.camp.owner) end
		end)
		self.toast = t
	end
	t.camp = camp
	t.title:SetText(L["A campfire in %s"]:format(W.Esc(W.ZoneName(camp.map))))
	local line = W.Esc(camp.owner) .. (camp.note ~= "" and (": " .. W.Esc(camp.note)) or (" " .. L["lit a camp."]))
	if W.Camps:OtherCopy(camp) == true then line = UI.C.copy .. L["another copy"] .. UI.C.r .. "  " .. line end
	t.line:SetText(line)
	Motion.Enter(t, -24)
	token = token + 1
	local mine = token
	C_Timer.After(8, function()
		if token == mine and t:IsShown() then Motion.Leave(t) end
	end)
end

--------------------------------------------------------------------------------
-- A question with two answers. One at a time: a second one waits for the first.
--------------------------------------------------------------------------------
local queue = {}
local function Next()
	local p, q = UI.prompt, queue[1]
	if not q or (p and p:IsShown()) then return end
	if not p then
		p = Card(380, 132, -220)
		p.line:SetWordWrap(true)
		p.line:SetSpacing(3)
		p.yes = Wd.Button(p, true)
		p.yes:SetPoint("BOTTOMLEFT", 66, 12)
		p.yes:SetSize(150, 28)
		p.no = Wd.Button(p)
		p.no:SetPoint("LEFT", p.yes, "RIGHT", 8, 0)
		p.no:SetSize(140, 28)
		UI.prompt = p
	end
	local function answer(value)
		return function()
			table.remove(queue, 1)
			p:Hide()
			q.fn(value)
			Next()
		end
	end
	p.title:SetText(q.title)
	p.line:SetText(q.text)
	p.yes:Set(q.yes)
	p.no:Set(q.no)
	p.yes.fn, p.no.fn = answer(true), answer(false)
	Motion.Enter(p, -24)
end
function UI.Ask(title, text, yes, no, fn)
	queue[#queue + 1] = { title = title, text = text, yes = yes, no = no, fn = fn }
	Next()
end

W:On("CAMP_NEW", function(camp)
	local map = W.Position()
	if W.db.toast and map and map == camp.map then UI:Toast(camp) end
end)

W:On("CONSENT_NEEDED", function()
	UI.Ask(L["Appear in circles?"],
		L["When you stand by an announced campfire, other Warmth players will see your name, your class and the camp object you placed. You can change this in the options."],
		L["Yes, show me"], L["No"], function(yes)
			W.db.consent = yes
			if yes then W.Watch:Tick() end
		end)
end)

W:On("INVITE_REQUEST", function(name)
	UI.Ask(L["%s wants to come to your fire"]:format(W.Esc(name)),
		L["They are in another copy of the zone. Inviting them to your group brings them to yours."],
		L["Invite"], L["Not now"], function(yes) W.Net:AnswerInvite(name, yes) end)
end)

local told
W:On("LIT", function()
	if told then return end
	told = true
	W.Print(L["Campfire lit. Open Warmth to announce it; nothing was sent."])
end)
