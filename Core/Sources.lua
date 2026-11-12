--=============================================================================
-- How a camp material is obtained, when nobody sells it: gathered from nodes, dropped by creatures, made with a
-- profession, skinned, fished or disenchanted.
--
-- Two kinds of knowledge meet here. Core/SourceData.lua (generated from the QuestieDB of Forever) says which
-- zones have the most nodes of an item and which creatures drop it. The table below is what that database does
-- not hold: recipes one step back (a bar from its ore), and the level bands for leather, cloth and enchanting
-- materials. It is general knowledge of the Classic game, NOT measured on Forever: the wording stays "around".
--=============================================================================
local _, W = ...
local Sources = {}
W.Sources = Sources

-- English names of materials the recipes do not name themselves (what a bar or a bolt is made of): the fallback
-- of W.ItemName until the client has the item cached.
W.MATERIAL_NAME = { [2770] = "Copper Ore", [2771] = "Tin Ore", [2772] = "Iron Ore", [2775] = "Silver Ore", [7911] = "Truesilver Ore",
	[10620] = "Thorium Ore", [3576] = "Tin Bar", [2836] = "Coarse Stone", [2589] = "Linen Cloth", [2592] = "Wool Cloth",
	[4306] = "Silk Cloth", [4338] = "Mageweave Cloth", [14047] = "Runecloth", [1475] = "Small Venom Sac", [1288] = "Large Venom Sac",
	[2880] = "Weak Flux", [2840] = "Copper Bar", [2841] = "Bronze Bar", [12359] = "Thorium Bar" }

-- [item] = { "craft", profession, { { item, amount } } } | { "skin" | "cloth" | "disenchant", level from, to } | { "fish", "start" | "mid" }
Sources.HOW = {
	[2840] = { "craft", "Mining", { { 2770, 1 } } },                    -- Copper Bar
	[2841] = { "craft", "Mining", { { 2840, 1 }, { 3576, 1 } } },       -- Bronze Bar
	[3576] = { "craft", "Mining", { { 2771, 1 } } },                    -- Tin Bar
	[3575] = { "craft", "Mining", { { 2772, 1 } } },                    -- Iron Bar
	[2842] = { "craft", "Mining", { { 2775, 1 } } },                    -- Silver Bar
	[6037] = { "craft", "Mining", { { 7911, 1 } } },                    -- Truesilver Bar
	[12359] = { "craft", "Mining", { { 10620, 1 } } },                  -- Thorium Bar
	[3478] = { "craft", "Blacksmithing", { { 2836, 2 } } },             -- Coarse Grinding Stone
	[2996] = { "craft", "Tailoring", { { 2589, 2 } } },                 -- Bolt of Linen Cloth
	[4305] = { "craft", "Tailoring", { { 4306, 4 } } },                 -- Bolt of Silk Cloth
	[14048] = { "craft", "Tailoring", { { 14047, 5 } } },               -- Bolt of Runecloth
	[1251] = { "craft", "First Aid", { { 2589, 1 } } },                 -- Linen Bandage
	[8544] = { "craft", "First Aid", { { 4338, 1 } } },                 -- Mageweave Bandage
	[14530] = { "craft", "First Aid", { { 14047, 2 } } },               -- Heavy Runecloth Bandage
	[6452] = { "craft", "First Aid", { { 1475, 1 } } },                 -- Anti-Venom
	[6453] = { "craft", "First Aid", { { 1288, 1 } } },                 -- Strong Anti-Venom
	[4359] = { "craft", "Engineering", { { 2840, 1 } } },               -- Handful of Copper Bolts
	[4361] = { "craft", "Engineering", { { 2840, 2 }, { 2880, 1 } } },  -- Copper Tube
	[4375] = { "craft", "Engineering", { { 2841, 2 }, { 2592, 1 } } },  -- Whirring Bronze Gizmo
	[4371] = { "craft", "Engineering", { { 2841, 2 }, { 2880, 1 } } },  -- Bronze Tube
	[15994] = { "craft", "Engineering", { { 12359, 3 }, { 14047, 1 } } }, -- Thorium Widget
	[2318] = { "skin", 1, 20 }, [2319] = { "skin", 15, 30 }, [4234] = { "skin", 25, 40 }, [8170] = { "skin", 40, 55 },
	[2589] = { "cloth", 5, 18 }, [2592] = { "cloth", 15, 28 }, [4306] = { "cloth", 25, 40 }, [4338] = { "cloth", 40, 50 }, [14047] = { "cloth", 50, 60 },
	[10940] = { "disenchant", 5, 25 }, [11137] = { "disenchant", 36, 45 }, [11174] = { "disenchant", 36, 40 },
	[14344] = { "disenchant", 51, 60 }, [16203] = { "disenchant", 51, 60 },
	[6291] = { "fish", "start" }, [8365] = { "fish", "mid" },
}

-- Zones a player is not sent to: the other faction's home zones and cities (uiMapIDs).
local HOME = {
	Alliance = { 1429, 1426, 1438, 1436, 1432, 1439, 1453, 1455, 1457 },
	Horde = { 1411, 1412, 1420, 1421, 1454, 1456, 1458 }, -- The Barrens is not here: both factions quest in it
}
local avoid
function Sources.Avoid(map)
	if not avoid then
		avoid = {}
		local mine = UnitFactionGroup and UnitFactionGroup("player")
		for side, zones in pairs(HOME) do
			if mine and side ~= mine then
				for _, zone in ipairs(zones) do avoid[zone] = true end
			end
		end
	end
	return avoid[map] == true
end

Sources.FEW = 5 -- fewer vendors than this is a limited stock somewhere: another way to get the item comes first

-- Up to two zones where the item is found, the best first, never in the other faction's home.
-- kind "nodes": { map, count }   kind "mobs": { map, count, from, to, creature }
function Sources:Places(item)
	local data = W.SOURCE_DATA and W.SOURCE_DATA[item]
	if not data then return nil end
	-- an ore's vein beats the creature that sometimes carries the ore; but if every zone with nodes is the other
	-- faction's home, the creatures are the way
	for _, kind in ipairs({ "nodes", "mobs" }) do
		local out = {}
		for _, p in ipairs(data[kind == "nodes" and "n" or "m"] or {}) do
			if #out < 2 and not Sources.Avoid(p[1]) then out[#out + 1] = { map = p[1], count = p[2], from = p[3], to = p[4], creature = p[5] } end
		end
		if #out > 0 then return kind, out end
	end
	return nil
end

-- How to get an item: { kind = "vendor" | "craft" | "nodes" | "mobs" | "skin" | "cloth" | "disenchant" | "fish" | "unknown", ... }
function Sources:Get(item)
	local how = self.HOW[item]
	local vendor, yards, heard = W.Workshop:Vendor(item)
	local sellers = 0
	for _ in pairs(W.Workshop:Sellers(item, true)) do sellers = sellers + 1 end -- trusted ones: hearsay cannot make an item "sold everywhere"
	if vendor and sellers >= self.FEW then return { kind = "vendor", vendor = vendor, yards = yards } end
	-- what is known of how the item is made or won comes before the database's places: for leather and cloth the
	-- database lists a chest or a handful of creatures, which would read as "gathered" or "dropped by one mob"
	if how and how[1] == "craft" then return { kind = "craft", profession = how[2], from = how[3] } end
	if how then return { kind = how[1], from = how[2], to = how[3] } end
	local kind, places = self:Places(item)
	if kind then return { kind = kind, places = places } end
	if vendor then return { kind = "vendor", vendor = vendor, yards = yards, heard = heard } end
	return { kind = "unknown" }
end

-- The fallback names reach W.ItemName through here.
local itemName = W.ItemName
function W.ItemName(item, fallback)
	return itemName(item, W.MATERIAL_NAME[item] or fallback)
end
