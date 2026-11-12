--=============================================================================
-- Warmth: player-lit campfires on the map, over the ChehulNet network.
--
-- This file owns the namespace, the saved variables and a small event hub. The core (Core/) never touches a
-- frame; the UI (UI/) listens with W:On and calls the core.
--=============================================================================
local ADDON, W = ...
_G.Warmth = W

local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
W.VERSION = (type(version) == "string" and not version:find("@", 1, true)) and version or "dev"
W.me = ""

-- consent: nil = never asked, true/false = the player's answer to "appear in circles?"
-- auto: a campfire the player lights is announced by itself (the owner's decision, 2026-11-12; it can be turned off)
local DEFAULTS = { toast = true, lessMotion = false, pins = true, invites = true, auto = true, compass = true }

local handlers = {}
function W:On(event, fn)
	handlers[event] = handlers[event] or {}
	table.insert(handlers[event], fn)
end
function W:Fire(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name ~= ADDON then return end
		WarmthDB = type(WarmthDB) == "table" and WarmthDB or {}
		for k, v in pairs(DEFAULTS) do
			if WarmthDB[k] == nil then WarmthDB[k] = v end
		end
		WarmthDB.meshPeers = type(WarmthDB.meshPeers) == "table" and WarmthDB.meshPeers or {}
		W.db = WarmthDB
		W:Fire("LOADED")
	else
		W.me = W.MyName()
		W:Fire("LOGIN")
	end
end)
