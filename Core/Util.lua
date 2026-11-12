--=============================================================================
-- Small helpers the core and the UI share: secrets, names, escaping, bags, where the player is.
--=============================================================================
local _, W = ...

-- A value the client marks secret (chat lockdown, restricted units) cannot be compared or indexed.
function W.IsSecret(...)
	if not issecretvalue then return false end
	for i = 1, select("#", ...) do
		local ok, s = pcall(issecretvalue, (select(i, ...)))
		if ok and s then return true end
	end
	return false
end

function W.Short(name)
	if type(name) ~= "string" or name == "" then return nil end
	return (Ambiguate and Ambiguate(name, "short")) or name
end

-- '|' opens an escape in WoW text ("|H" starts a link): every string from the network passes here before display.
function W.Esc(s)
	return (tostring(s == nil and "" or s):gsub("|", "||"):gsub("%c", "?"))
end

function W.Print(...)
	print("|cffffb454Warmth|r", ...)
end

-- On Forever a sender is "First Surname" (the same rule ChehulNet uses for its own name).
function W.MyName()
	if C_PlayerInfo and C_PlayerInfo.ShouldDisplaySurname and C_PlayerInfo.ShouldDisplaySurname() then
		local first, surname = UnitFullName("player")
		if not W.IsSecret(first, surname) and first and surname and surname ~= "" then return first .. " " .. surname end
	end
	return UnitName("player") or ""
end

function W.MyClassIndex()
	local _, token = UnitClass("player")
	return W.CLASS_INDEX[token or ""] or 0
end

-- The item's name in the client's language once the client knows it; the English name until then.
function W.ItemName(item, fallback)
	local f = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
	if f then
		local ok, name = pcall(f, item)
		if ok and type(name) == "string" and name ~= "" and not W.IsSecret(name) then return name end
	end
	return fallback
end
function W.ObjectName(index)
	local o = W.OBJECTS[index]
	return o and W.ItemName(o[1], o[2]) or "?"
end

function W.Count(item)
	local f = (C_Item and C_Item.GetItemCount) or GetItemCount
	if not f then return 0 end
	local ok, n = pcall(f, item)
	return ok and tonumber(n) or 0
end

-- map, x, y (0..1) of the player; nil where the game gives no position (instances).
function W.Position()
	local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not x or not y or (x == 0 and y == 0) then return nil end
	return map, x, y
end

-- World position (yards; first grows north, second grows west) of a point on a map, and its continent; nil when
-- the client won't say.
function W.World(map, x, y)
	if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
	local ok, continent, v = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
	if not (ok and v) then return nil end
	local n, w = v:GetXY()
	return n, w, continent
end

-- Yards from the player to a camp on the player's map; nil for another map.
function W.Distance(camp)
	local map, x, y = W.Position()
	if not map or map ~= camp.map then return nil end
	local an, aw = W.World(map, x, y)
	local bn, bw = W.World(map, camp.x, camp.y)
	if not (an and bn) then return nil end
	return math.sqrt((an - bn) ^ 2 + (aw - bw) ^ 2)
end

-- Is there a lit campfire in range of the player, in the player's copy of the zone? The game says so with an aura.
-- true / false, or nil where the client cannot tell (no aura API, or the answer is secret).
function W.HasAura(id)
	local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not get then return nil end
	local ok, aura = pcall(get, id)
	if not ok or W.IsSecret(aura) then return nil end
	return aura ~= nil
end
function W.FireNearby() return W.HasAura(W.AURA.NEARBY) end

function W.ZoneName(map)
	local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return (info and info.name) or ("#" .. tostring(map))
end

-- The copy (layer) of `map` this client is in, as ChehulNet learned it; 0 when unknown or for another map.
function W.MyCopy(map)
	local CN = _G.ChehulNet
	if not (CN and CN.MyLayer) then return 0 end
	local ok, m, z = pcall(CN.MyLayer, CN)
	if ok and m == map and type(z) == "number" and z > 0 then return z end
	return 0
end
