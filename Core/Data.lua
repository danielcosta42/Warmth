--=============================================================================
-- What the game calls things. Ids come from third-party guides (wow-professions.com, November 2026) and are NOT
-- verified in game yet: everything built on them has a manual path (see the spec, section 4).
--
-- The order of W.OBJECTS is part of the wire format (an object travels as its index): append, never reorder.
--=============================================================================
local _, W = ...

W.TIERS = { "Basic", "Journeyman", "Expert" }
W.SLOTS = { 3, 5, 10 }
W.KITS  = { 279981, 279961, 279974 }
W.WOOD  = { { 4470, "Simple Wood" }, { 11291, "Star Wood" }, { 272941, "Thick Logs" } }

-- Wire order of classes: a class travels as one letter, 'a' = unknown.
W.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
	"DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" }
W.CLASS_INDEX = {}
for i, token in ipairs(W.CLASSES) do W.CLASS_INDEX[token] = i end

-- { item id, name, profession, what it gives (nil: a crafting station) }
W.OBJECTS = {
	{ 279956, "Mana Well", "Alchemy", "Mana regeneration" },
	{ 279970, "Fermenter", "Alchemy" },
	{ 279990, "Alchemy Laboratory", "Alchemy" },
	{ 279944, "Sharpening Wheel", "Blacksmithing", "Strength" },
	{ 279988, "Anvil", "Blacksmithing", "A usable anvil" },
	{ 279955, "Master Forge", "Blacksmithing", "A usable forge" },
	{ 279976, "Enchanted Lute", "Enchanting", "Armor and all stats" },
	{ 279985, "Arcane Salvager", "Enchanting" },
	{ 279987, "Arcane Forge", "Enchanting" },
	{ 279950, "Reagent Bot", "Engineering", "Reagent vendor" },
	{ 279949, "Repair Bot", "Engineering", "Repairs" },
	{ 279989, "Anarchist's Workbench", "Engineering" },
	{ 279962, "Incense Candle", "Herbalism", "Intellect" },
	{ 279964, "Greenhouse", "Herbalism", "Grows herbs" },
	{ 279947, "Seed Hybridizer", "Herbalism" },
	{ 279978, "Camp Tent", "Leatherworking", "Rested experience" },
	{ 279941, "Tanning Rack", "Leatherworking" },
	{ 279945, "Sewing Machine", "Leatherworking" },
	{ 279960, "Lodestone", "Mining", "Attack power" },
	{ 279948, "Rock Garden", "Mining", "A mining node" },
	{ 279952, "Molten Foundry", "Mining" },
	{ 279979, "Camp Chair", "Skinning", "+2% critical strike" },
	{ 279969, "Field Guide", "Skinning", "Track Beasts" },
	{ 279938, "Trapper's Workbench", "Skinning" },
	{ 279972, "Faction Banner", "Tailoring", "Spirit" },
	{ 279943, "Spinning Wheel", "Tailoring" },
	{ 279959, "Loom", "Tailoring" },
	{ 279957, "Cookie's Feast", "Cooking", "Stamina food" },
	{ 279982, "Iron Oven", "Cooking" },
	{ 279968, "First Aid Kit", "First Aid", "Stamina" },
	{ 279940, "Toxin Study", "First Aid" },
	{ 279951, "Plague Doctor's Laboratory", "First Aid" },
	{ 279967, "Fish Bowl", "Fishing", "+8% all stats" },
	{ 279965, "Fishing Rack", "Fishing" },
	{ 279966, "Fishing Hut", "Fishing" },
}
W.OBJECT_BY_ID = {}
for i, o in ipairs(W.OBJECTS) do W.OBJECT_BY_ID[o[1]] = i end
W.TENT, W.REPAIR = W.OBJECT_BY_ID[279978], W.OBJECT_BY_ID[279949]

W.COOKING_SPELL = 2550 -- the Cooking profession spell, for its localized name
