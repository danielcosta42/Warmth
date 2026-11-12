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
-- `title` and `line` replace the usual "a campfire in <zone>" (a camp asking for an object, for one).
function UI:Toast(camp, title, line)
	local t = self.toast
	if not t then
		t = Card(340, 60, -150)
		t:SetScript("OnClick", function(card)
			card:Hide()
			if card.camp then UI:Show("camp", card.camp.owner) end
		end)
		self.toast = t
	end
	t.camp = camp
	t.glow:SetViolet(W.Camps:Violet(camp))
	t.flame:SetViolet(W.Camps:Violet(camp))
	if not title then
		title = L["A campfire in %s"]:format(W.Esc(W.ZoneName(camp.map)))
		line = camp.sight and UI.CampTitle(camp) or W.Esc(camp.owner) .. (camp.note ~= "" and (": " .. W.Esc(camp.note)) or (" " .. L["lit a camp."]))
		if W.Camps:OtherCopy(camp) == true then line = UI.C.copy .. L["another copy"] .. UI.C.r .. "  " .. line end
	end
	t.title:SetText(title)
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

W:On("BURNED", function(tier, seconds)
	W.Print(L["Your %s campfire burned for %d min %d s."]:format(L[W.TIERS[tier]], math.floor(seconds / 60), seconds % 60))
end)

-- A camp nearby asks for an object this player carries or can craft: once per camp and object.
local answered = {}
W:On("CAMP_WANTS", function(camp)
	if not W.db.toast or camp.owner == W.me or W.Camps:OtherCopy(camp) == true then return end
	local d = W.Distance(camp)
	if not d or d > 1500 then return end
	local index, how = W.Social:CanAnswer(camp)
	if not index or answered[camp.owner .. index] then return end
	answered[camp.owner .. index] = true
	UI:Toast(camp, L["A camp needs a %s"]:format(W.ObjectName(index)),
		UI.CampTitle(camp) .. ", " .. UI.Where(camp) .. ". " .. (how == "bags" and L["You carry one."] or L["You can craft one."]))
end)

W:On("THANKED", function(who, points, level)
	W.Print(L["%s thanked you for the fire. Your warmth: %d."]:format(W.Esc(who), points))
	if level then W.Print(L["You are now a %s host."]:format(L[W.Social.LEVELS[level]])) end
end)

W:On("FIRE_OUT", function()
	W.Print(L["Your fire went out: the announce ended."])
end)

local told
W:On("AUTO_ANNOUNCED", function()
	if told then return end
	told = true
	W.Print(L["Campfire lit and announced to the network. (You can turn the automatic announce off in the options.)"])
end)
local toldSight
W:On("SIGHTED", function()
	if toldSight then return end
	toldSight = true
	W.Print(L["You passed a campfire the network did not know: it is on the map now. (The automatic announce can be turned off in the options.)"])
end)
W:On("LIT", function()
	if told or W.db.auto ~= false then return end
	told = true
	W.Print(L["Campfire lit. Open Warmth to announce it; it has not been announced."])
end)
