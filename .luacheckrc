-- luacheck for Warmth on WoW: Forever (interface 16001, Lua 5.1).
--
-- Undefined globals are errors. read_globals is every engine global the addon reads, so it doubles as the API
-- inventory: a new name goes here only after checking it exists on the Forever client (or is used guarded).
--
-- CI runs `luacheck Core UI`. Out of it: the vendored libraries and the harnesses in tools/.

std = "lua51"
max_line_length = 160
codes = true
self = false -- an unused implicit self in a method is the method shape, not a mistake

globals = {
    "Warmth", "WarmthDB", "SlashCmdList", "SLASH_WARMTH1",
    "Warmth_OnCompartmentClick", "Warmth_OnCompartmentEnter", "Warmth_OnCompartmentLeave",
}

read_globals = {
    -- Lua environment WoW adds
    "strsplit", "time", "date", "issecretvalue", "geterrorhandler", "hooksecurefunc", "tinsert",
    -- frames
    "CreateFrame", "UIParent", "GameTooltip", "Minimap", "WorldMapFrame", "UISpecialFrames",
    "ChatFrameUtil", "ChatFrame_AddMessageEventFilter", "Settings", "InterfaceOptions_AddCategory",
    -- constants
    "RAID_CLASS_COLORS", "CLASS_ICON_TCOORDS", "ERR_CHAT_PLAYER_NOT_FOUND_S", "STANDARD_TEXT_FONT",
    -- client, units
    "GetLocale", "GetTime", "GetCVar", "GetPlayerFacing", "Ambiguate", "UnitName", "UnitFullName", "UnitClass",
    "InviteUnit", "UnitGUID", "UnitAura", "InCombatLockdown", "GetBuildInfo", "IsResting", "GetRestState",
    "GetXPExhaustion",
    -- items, spells, professions (the classic trade skill API is used guarded)
    "GetItemCount", "GetItemSpell", "GetItemIcon", "GetItemInfo", "GetSpellInfo",
    "GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo",
    -- maps
    "CreateVector2D", "UiMapPoint",
    -- namespaces
    "C_AddOns", "C_CVar", "C_Item", "C_Map", "C_UnitAuras", "C_VignetteInfo", "C_PartyInfo", "C_PlayerInfo", "C_Spell", "C_TradeSkillUI", "C_SuperTrack", "C_Timer",
}

files["Core/Locale.lua"] = { max_line_length = false }
files["UI/Views.lua"] = { max_line_length = false }
files["UI/Toast.lua"] = { max_line_length = false }
files["UI/Entry.lua"] = { max_line_length = false }
files["UI/Compass.lua"] = { max_line_length = false }
files["UI/Options.lua"] = { max_line_length = false }
files["Core/Probe.lua"] = { max_line_length = false }

exclude_files = { ".release/", "Libs/", "tools/" }
