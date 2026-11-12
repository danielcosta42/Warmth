--=============================================================================
-- What the game calls things. The item ids came from third-party guides (wow-professions.com, November 2026) and
-- all 41 were confirmed in game with /warmth probe on build 1.60.1.70888: each resolves to a name and a spell.
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

-- The Cozy Sleeping Bag (measured 2026-11-11): using it casts Unroll Bag (429961, 15 s), the player becomes
-- rested, and about a minute later gets Well-Rested (429959, 2 hours). The owner's word on what it is worth: 1%
-- experience per minute lying in it, up to 3%, and it goes together with the campfire.
W.SLEEPING_BAG = 211527

W.COOKING_SPELL = 2550 -- the Cooking profession spell, for its localized name

-- Auras the game puts on the player around a campfire (measured with /warmth probe, build 1.60.1.70888).
W.AURA = {
	NEARBY   = 1283391, -- "Campfire Nearby": on while a lit campfire is in range, whoever lit it
	WELCOME  = 1229739, -- "Welcoming Campfire": the minute of resting by the fire, 60 s
	BENEFITS = 1229741, -- "Camp Benefits": what the minute gives; 1 hour, 2 hours from a fire with violet flames
	RESTED   = 429959,  -- "Well-Rested": from the Cozy Sleeping Bag
	VIOLET   = 1328375, -- "Violet Flames": by a fire someone threw Violet Dust into (the launch celebration toy);
	                    -- such a fire gives its benefits for 2 hours instead of 1 (the owner, 2026-11-11)
}
