--=============================================================================
-- How the player gets in: the game's addon compartment (declared in the toc, with the icon) and /warmth.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, L = UI.T, W.L

-- Left click opens or closes the window; right click goes straight to setting up a camp.
function Warmth_OnCompartmentClick(_, button)
	if button == "RightButton" then UI:Show("build") else UI:Toggle() end
end

function Warmth_OnCompartmentEnter(_, menuButton)
	local camps, people = W.Camps:List(), 0
	for _, camp in ipairs(camps) do people = people + W.Camps:Count(camp) end
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	GameTooltip:SetText("Warmth", T.ember[1], T.ember[2], T.ember[3])
	GameTooltip:AddLine(#camps == 0 and L["No campfire announced on the network right now."]
		or L["%d on the network now, %d people around the fires."]:format(#camps, people), 1, 1, 1, true)
	GameTooltip:AddLine(L["Click: open.  Right click: set up a camp."], T.mute[1], T.mute[2], T.mute[3])
	GameTooltip:Show()
end

function Warmth_OnCompartmentLeave()
	GameTooltip:Hide()
end

--------------------------------------------------------------------------------
-- /warmth demo: three camps on this client only, to see the addon with nobody around. Nothing is sent, and the
-- core never whispers, joins or asks an invite at a camp flagged demo.
--------------------------------------------------------------------------------
local DEMO = {
	{ "Ana Lima", 0.03, -0.02, 2, "tent and repairs, come on over", { W.TENT, 1, W.REPAIR },
		{ { "Ana Lima", 9 }, { "Caio Nunes", 7 }, { "Bia Rocha", 2 }, { "Davi Sol", 3 } }, 4 },
	{ "Rui Novo", -0.12, 0.09, 1, "", { W.TENT }, { { "Rui Novo", 1 } }, 1 },
	{ "Lia Velha", -0.2, -0.13, 3, "the whole guild is here", { W.TENT, 1, W.REPAIR, 13, 33, 4, 22 },
		{ { "Lia Velha", 8 }, { "Jo Prata", 4 }, { "Teo Mar", 6 }, { "Nina Paz", 5 }, { "Gil Rocha", 3 }, { "Iva Luz", 7 },
			{ "Oto Rei", 1 }, { "Mel Dias", 9 }, { "Ravi Sul", 2 } }, 14 },
}
local function Demo()
	local map, x, y = W.Position()
	if not map then return W.Print(L[UI.REASONS.no_position]) end
	for _, d in ipairs(DEMO) do
		local people = {}
		for i, p in ipairs(d[7]) do people[i] = { name = p[1], class = p[2] } end
		local camp = W.Camps:Announce(d[1], { map = map, x = math.min(0.95, math.max(0.05, x + d[2])), y = math.min(0.95, math.max(0.05, y + d[3])),
			zuid = 0, tier = d[4], n = d[8], objs = d[6], people = people, note = d[5] })
		if camp then
			camp.demo = true
			camp.last = time() + 86400 -- stays for the session
		end
	end
	W.Print(L["Three demo camps on this map (only you see them). /warmth clear removes them."])
	UI:Show("list")
end
local function ClearDemo()
	for owner, camp in pairs(W.Camps.all) do
		if camp.demo then W.Camps:End(owner) end
	end
end

SLASH_WARMTH1 = "/warmth"
SlashCmdList.WARMTH = function(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	if cmd == "" then UI:Toggle()
	elseif cmd == "setup" then UI:Show("build")
	elseif cmd == "options" then UI.OpenOptions()
	elseif cmd == "demo" then Demo()
	elseif cmd == "clear" then ClearDemo()
	else W.Print(L["/warmth opens the window. Also: setup, options, demo, clear."]) end
end
