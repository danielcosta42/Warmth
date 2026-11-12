--=============================================================================
-- The probe: a recorder for finding out what the Forever client reveals about camping. Off unless asked for.
--
--   /warmth probe            start; again to stop
--   /warmth probe <words>    while running: a mark in the recording ("lit basic", "sat down", "placed chair")
--
-- While it runs it writes what it sees into WarmthDB.probe: which APIs exist, what the client says about the kit
-- and object items (name, spell, count), the player's professions and which camp recipes they know, and a
-- time-stamped log of the player's casts, aura changes, system and error lines, vignettes, tooltips shown, the
-- object under the interact key, bag changes of camp items, and what a profession window, a merchant, a trainer
-- and a quest giver show when opened.
-- Nothing is sent anywhere: the recording stays in the SavedVariables file, to be read after a /reload.
--=============================================================================
local _, W = ...
local Probe = { on = false }
W.Probe = Probe

local LOG_MAX = 800
local t0, rec, frame = 0, nil, nil

-- A value as text; a secret one (chat lockdown, restricted units) is only named.
local function S(v)
	if W.IsSecret(v) then return "<secret>" end
	if v == nil then return "nil" end
	return (tostring(v):gsub("[%c|]", " "))
end

local function Log(what, ...)
	if not (Probe.on and rec) then return end
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = S((select(i, ...))) end
	if #rec.log >= LOG_MAX then table.remove(rec.log, 1) end
	rec.log[#rec.log + 1] = string.format("%7.1f  %-22s %s", GetTime() - t0, what, table.concat(parts, "  "))
end
Probe.Log = Log

-- fn(...)'s results, or nothing if it is missing or throws. Passed through varargs, so a nil in the middle of the
-- results does not cut the rest off.
local function Results(ok, ...)
	if ok then return ... end
end
local function Safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	return Results(pcall(fn, ...))
end

local function SpellName(id)
	if W.IsSecret(id) or type(id) ~= "number" then return "?" end
	return Safe(C_Spell and C_Spell.GetSpellName, id) or Safe(GetSpellInfo, id) or "?"
end

--------------------------------------------------------------------------------
-- Snapshots
--------------------------------------------------------------------------------
-- Names the addon would like to lean on: which of them exist on this client.
local API = { "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetPlayerAuraBySpellID", "UnitAura", "UnitBuff",
	"C_VignetteInfo.GetVignettes", "C_VignetteInfo.GetVignetteInfo", "C_VignetteInfo.GetVignettePosition",
	"C_Item.GetItemSpell", "GetItemSpell", "C_Item.GetItemNameByID", "C_Item.GetItemCount", "C_Item.GetItemIconByID",
	"C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "C_Container.UseContainerItem",
	"GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo", "C_TradeSkillUI.GetAllRecipeIDs",
	"C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetBaseProfessionInfo", "GetProfessions", "GetNumSkillLines",
	"GetSkillLineInfo", "C_Spell.GetSpellName", "C_Spell.GetSpellInfo", "GetSpellInfo", "IsPlayerSpell", "IsSpellKnown",
	"C_Map.SetUserWaypoint", "C_SuperTrack.SetSuperTrackingUserWaypoint", "C_Map.GetWorldPosFromMapPos",
	"C_Map.GetMapPosFromWorldPos", "GetPlayerFacing", "InCombatLockdown", "C_PartyInfo.InviteUnit", "InviteUnit",
	"UnitGUID", "C_CVar.GetCVar", "DoEmote", "IsResting", "GetRestState", "GetXPExhaustion",
	"C_Minimap.GetNumTrackingTypes", "C_GameRules.IsGameRuleActive", "Settings.RegisterCanvasLayoutCategory",
	"AddonCompartmentFrame.RegisterAddon", "C_TooltipInfo.GetWorldCursor", "C_TooltipInfo.GetUnit",
	-- for the Workshop: professions, known recipes, what a recipe takes, merchants, trainers
	"C_TradeSkillUI.GetAllProfessionTradeSkillLines", "C_TradeSkillUI.GetProfessionInfoBySkillLineID",
	"C_TradeSkillUI.GetRecipeSchematic", "C_TradeSkillUI.OpenTradeSkill", "C_TradeSkillUI.CraftRecipe", "GetProfessionInfo",
	"C_SpellBook.IsSpellKnown", "C_SpellBook.IsSpellInSpellBook", "C_Spell.IsSpellUsable",
	"GetMerchantNumItems", "GetMerchantItemID", "GetMerchantItemInfo", "C_MerchantFrame.GetItemInfo", "C_MerchantFrame.GetNumItems",
	"GetNumTrainerServices", "GetTrainerServiceInfo", "C_QuestLog.IsQuestFlaggedCompleted", "C_Item.GetItemInfo", "GetItemInfo" }

local function Exists(path)
	local v = _G
	for part in path:gmatch("[^%.]+") do
		if type(v) ~= "table" then return false end
		v = v[part]
	end
	return v ~= nil
end

local function Auras()
	local out = {}
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 1, 60 do
			local name, id, duration, source
			local a = Safe(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
			if a then
				name, id, duration, source = a.name, a.spellId, a.duration, a.sourceUnit
			elseif UnitAura then
				local n, _, _, _, d, _, src, _, _, sid = Safe(UnitAura, "player", i, filter)
				name, id, duration, source = n, sid, d, src
			end
			if not name then break end
			if not W.IsSecret(id) and id then
				out[id] = string.format("%s  id=%s  %s  duration=%s  from=%s", S(name), S(id), filter, S(duration), S(source))
			else
				out[filter .. i] = string.format("%s  id=%s  %s", S(name), S(id), filter)
			end
		end
	end
	return out
end

local function Vignettes()
	local out = {}
	local map = W.Position()
	for _, guid in ipairs(Safe(C_VignetteInfo and C_VignetteInfo.GetVignettes) or {}) do
		local v = Safe(C_VignetteInfo.GetVignetteInfo, guid)
		if v then
			local pos = map and Safe(C_VignetteInfo.GetVignettePosition, guid, map)
			local x, y = 0, 0
			if pos and pos.GetXY then x, y = pos:GetXY() end
			out[S(guid)] = string.format("%s  id=%s  atlas=%s  type=%s  object=%s  at %.3f,%.3f", S(v.name), S(v.vignetteID),
				S(v.atlasName), S(v.type), S(v.objectGUID), x or 0, y or 0)
		end
	end
	return out
end

local function Items()
	local out = {}
	local function add(kind, id, guide)
		local spellName, spellID = Safe((C_Item and C_Item.GetItemSpell) or GetItemSpell, id)
		out[#out + 1] = string.format("%-8s %d  guide=%s  client=%s  spell=%s (%s)  bags=%d", kind, id, guide,
			S(W.ItemName(id, nil)), S(spellID), S(spellName), W.Count(id))
	end
	for i, kit in ipairs(W.KITS) do add("kit" .. i, kit, W.TIERS[i] .. " Campfire Kit") end
	for _, wood in ipairs(W.WOOD) do add("wood", wood[1], wood[2]) end
	add("bag", W.SLEEPING_BAG, "Sleeping Bag")
	for _, o in ipairs(W.OBJECTS) do add("object", o[1], o[2]) end
	return out
end

-- A table's plain fields as "k=v k=v" (nested tables are only counted).
local function Dump(t, max)
	local parts = {}
	for k, v in pairs(type(t) == "table" and t or {}) do
		if #parts < (max or 16) then parts[#parts + 1] = S(k) .. "=" .. (type(v) == "table" and ("{" .. #v .. "}") or S(v)) end
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

-- The player's professions as the client tells them, by every way it might.
local function Professions()
	local out = {}
	local TS = C_TradeSkillUI
	for _, line in ipairs(Safe(TS and TS.GetAllProfessionTradeSkillLines) or {}) do
		local info = Safe(TS.GetProfessionInfoBySkillLineID, line)
		if type(info) == "table" and (tonumber(info.skillLevel) or 0) > 0 then out[#out + 1] = "line " .. S(line) .. ": " .. Dump(info) end
	end
	if GetProfessions and GetProfessionInfo then
		for slot, index in pairs({ Safe(GetProfessions) }) do
			if index then
				local name, _, rank, maxRank, _, _, skillLine = Safe(GetProfessionInfo, index)
				out[#out + 1] = string.format("GetProfessions slot %s: %s %s/%s line=%s", S(slot), S(name), S(rank), S(maxRank), S(skillLine))
			end
		end
	end
	return out
end

-- Each camp object's recipe spell (from the guide): what the client calls it and whether the player knows it.
local function Recipes()
	local out = {}
	for index, spell in ipairs(W.RECIPES) do
		out[#out + 1] = string.format("%-26s recipe=%d  client=%s  IsPlayerSpell=%s  IsSpellKnown=%s  spellbook=%s", W.OBJECTS[index][2], spell,
			S(Safe(C_Spell and C_Spell.GetSpellName, spell)), S(Safe(IsPlayerSpell, spell)), S(Safe(IsSpellKnown, spell)),
			S(Safe(C_SpellBook and C_SpellBook.IsSpellKnown, spell)))
	end
	return out
end

-- What changed between two snapshots (id -> description), logged as + and -.
local function Diff(what, before, after)
	for k, v in pairs(after) do
		if not before[k] then Log(what .. " +", v) end
	end
	for k, v in pairs(before) do
		if not after[k] then Log(what .. " -", v) end
	end
end

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------
local auras, vignettes, counts, lastTip, lastInteract = {}, {}, {}, nil, nil

local function Counts()
	local out = {}
	for _, kit in ipairs(W.KITS) do out[kit] = W.Count(kit) end
	out[W.SLEEPING_BAG] = W.Count(W.SLEEPING_BAG)
	for _, o in ipairs(W.OBJECTS) do out[o[1]] = W.Count(o[1]) end
	return out
end

local EVENTS = { "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_AURA", "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
	"VIGNETTES_UPDATED", "VIGNETTE_MINIMAP_UPDATED", "BAG_UPDATE_DELAYED", "PLAYER_UPDATE_RESTING",
	"PLAYER_SOFT_INTERACT_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "UPDATE_EXHAUSTION",
	"MERCHANT_SHOW", "TRAINER_SHOW", "QUEST_DETAIL", "QUEST_COMPLETE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local function OnEvent(_, event, a, b, c, d)
	if not Probe.on then return end
	if event:find("^UNIT_SPELLCAST") then
		if W.IsSecret(a) or a ~= "player" then return end
		if event == "UNIT_SPELLCAST_SENT" then Log(event, "target=" .. S(b), "spell=" .. S(d), SpellName(d))
		else Log(event, "spell=" .. S(c), SpellName(c)) end
	elseif event == "UNIT_AURA" then
		if W.IsSecret(a) or a ~= "player" then return end
		local now = Auras()
		Diff("aura", auras, now)
		auras = now
	elseif event == "VIGNETTES_UPDATED" or event == "VIGNETTE_MINIMAP_UPDATED" then
		local now = Vignettes()
		Diff("vignette", vignettes, now)
		vignettes = now
	elseif event == "BAG_UPDATE_DELAYED" then
		local now = Counts()
		for id, n in pairs(now) do
			if n ~= (counts[id] or 0) then Log("bags", id, W.ItemName(id, "?"), (counts[id] or 0) .. " -> " .. n) end
		end
		counts = now
	elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
		-- what the profession window says about itself and about one recipe that can be made
		local TS = C_TradeSkillUI
		local function dump(t)
			local parts = {}
			for k, v in pairs(type(t) == "table" and t or {}) do
				if #parts < 16 and type(v) ~= "table" then parts[#parts + 1] = S(k) .. "=" .. S(v) end
			end
			table.sort(parts)
			return table.concat(parts, " ")
		end
		local ids = Safe(TS and TS.GetAllRecipeIDs) or {}
		Log(event, "base: " .. dump(Safe(TS and TS.GetBaseProfessionInfo)), "recipes=" .. #ids)
		if event == "TRADE_SKILL_SHOW" then
			-- the first two recipes in full, every camp recipe in this profession, and what each takes
			local camp, shown = {}, 0
			for index, spell in ipairs(W.RECIPES) do camp[spell] = index end
			for _, id in ipairs(ids) do
				local info = Safe(TS.GetRecipeInfo, id)
				if type(info) == "table" and (shown < 2 or camp[id]) then
					shown = shown + 1
					Log(camp[id] and "camp recipe" or "recipe", "id=" .. S(id), Dump(info, 24))
					local schematic = Safe(TS.GetRecipeSchematic, id, false)
					for _, slot in ipairs(type(schematic) == "table" and schematic.reagentSlotSchematics or {}) do
						local reagent = type(slot.reagents) == "table" and slot.reagents[1] or {}
						Log("  takes", "item=" .. S(reagent.itemID), W.ItemName(reagent.itemID or 0, "?"), "x" .. S(slot.quantityRequired), "have=" .. W.Count(reagent.itemID or 0))
					end
				end
			end
		end
	elseif event == "MERCHANT_SHOW" then
		-- who sells what, and where: the Workshop wants to mark vendors of camp materials on the map
		local map, x, y = W.Position()
		Log(event, "npc=" .. S(Safe(UnitGUID, "npc")), S(Safe(UnitName, "npc")), string.format("map %s  %.4f, %.4f", S(map), x or 0, y or 0))
		local n = Safe(GetMerchantNumItems) or Safe(C_MerchantFrame and C_MerchantFrame.GetNumItems) or 0
		for i = 1, math.min(tonumber(n) or 0, 60) do
			local id = Safe(GetMerchantItemID, i)
			local info = Safe(C_MerchantFrame and C_MerchantFrame.GetItemInfo, i)
			local name, _, price = Safe(GetMerchantItemInfo, i)
			if type(info) == "table" then name, price = info.name, info.price end
			Log("  sells", "item=" .. S(id), S(name), "price=" .. S(price))
		end
	elseif event == "TRAINER_SHOW" then
		Log(event, "npc=" .. S(Safe(UnitGUID, "npc")), S(Safe(UnitName, "npc")))
		for i = 1, math.min(tonumber(Safe(GetNumTrainerServices)) or 0, 80) do
			local name, kind = Safe(GetTrainerServiceInfo, i)
			if kind ~= "header" then Log("  teaches", S(name), S(kind)) end
		end
	elseif event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
		Log(event, "quest=" .. S(Safe(GetQuestID)), S(Safe(GetTitleText)), "npc=" .. S(Safe(UnitGUID, "npc")), S(Safe(UnitName, "npc")))
	elseif event == "PLAYER_UPDATE_RESTING" or event == "UPDATE_EXHAUSTION" then
		Log(event, "resting=" .. S(Safe(IsResting)), "restState=" .. S(Safe(GetRestState)), "exhaustion=" .. S(Safe(GetXPExhaustion)))
	else
		Log(event, a, b, c, d)
	end
end

-- Once a second: the object under the interact key (its GUID carries the object's entry id) and a new tooltip.
local function Poll()
	local guid = Safe(UnitGUID, "softinteract")
	if not W.IsSecret(guid) and guid ~= lastInteract then
		lastInteract = guid
		Log("softinteract", guid, Safe(UnitName, "softinteract"))
	end
	local tip = _G.GameTooltip
	if tip and tip:IsShown() then
		local lines = {}
		for i = 1, 6 do
			local fs = _G["GameTooltipTextLeft" .. i]
			local text = fs and fs:GetText()
			if text and not W.IsSecret(text) and text ~= "" then lines[#lines + 1] = text end
		end
		local owner = tip:GetOwner()
		local key = table.concat(lines, " / ")
		if key ~= "" and key ~= lastTip then
			lastTip = key
			Log("tooltip", "owner=" .. S(owner and owner.GetName and owner:GetName() or owner and "unnamed" or "none"), key)
		end
	end
end

function Probe:Start()
	local build, number, _, interface = Safe(GetBuildInfo)
	local map, x, y = W.Position()
	rec = { started = date and date("%Y-%m-%d %H:%M:%S") or "?", warmth = W.VERSION, log = {}, api = {},
		client = string.format("build %s (%s) interface %s  locale %s  softInteract=%s", S(build), S(number), S(interface),
			S(Safe(GetLocale)), S(Safe(C_CVar and C_CVar.GetCVar, "SoftTargetInteract"))),
		where = string.format("map %s (%s)  %.3f, %.3f  copy %s", S(map), map and W.ZoneName(map) or "?", x or 0, y or 0, S(map and W.MyCopy(map))) }
	for _, name in ipairs(API) do rec.api[#rec.api + 1] = (Exists(name) and "yes  " or "NO   ") .. name end
	rec.items = Items()
	rec.professions = Professions()
	rec.recipes = Recipes()
	W.db.probe = rec
	t0, self.on = GetTime(), true
	auras, vignettes, counts, lastTip, lastInteract = Auras(), Vignettes(), Counts(), nil, nil
	for _, line in pairs(auras) do Log("aura at start", line) end
	for _, line in pairs(vignettes) do Log("vignette at start", line) end
	if not frame then
		frame = CreateFrame("Frame")
		for _, e in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, e) end
		frame:SetScript("OnEvent", OnEvent)
		local acc = 0
		frame:SetScript("OnUpdate", function(_, elapsed)
			acc = acc + elapsed
			if acc >= 1 and Probe.on then acc = 0; pcall(Poll) end
		end)
	end
end

function Probe:Stop()
	if not self.on then return 0 end
	rec.items = Items() -- again: the client may have learned item names and spells meanwhile
	rec.professions = Professions()
	rec.recipes = Recipes()
	rec.seconds = math.floor(GetTime() - t0)
	self.on = false
	return #rec.log
end

function Probe:Mark(text)
	Log("MARK", ">>> " .. tostring(text))
end
