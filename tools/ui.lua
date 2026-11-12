-- The whole addon (Core/ and UI/) under a simulated client: motion bounds, the three views, pins, toast,
-- questions, options, entry points and the ptBR table.
--   luajit tools/ui.lua        (from the repository root)
local S = dofile("tools/wowstub.lua")
local check = S.check
local W = S.load("Core/", "UI/")
S.fire("ADDON_LOADED", "Warmth")
S.fire("PLAYER_LOGIN")
local UI, Camps, Motion = W.UI, W.Camps, W.UI.Motion
local function announce(owner, f)
	local base = { map = 1411, x = 0.5, y = 0.5, zuid = 0, tier = 1, n = 1, objs = {}, people = {}, note = "" }
	for k, v in pairs(f or {}) do base[k] = v end
	return Camps:Announce(owner, base)
end
local function draws(what, fn)
	local ok, err = pcall(fn)
	check(ok, what .. " draws without error: " .. tostring(err))
end

-- ── the locale ─────────────────────────────────────────────────────────────
local keys = dofile("tools/keys.lua")(W)
check(#keys > 120, "the key list sees the strings: " .. #keys)
for _, k in ipairs(keys) do
	local t = W.LOCALES.ptBR[k]
	check(t ~= nil, "ptBR lacks: " .. k)
	local function specs(s) local out = {}; for spec in s:gmatch("%%[%d%.]*[dsf]") do out[#out + 1] = spec end; return table.concat(out) end
	check(specs(k) == specs(t), "ptBR keeps the format of: " .. k)
end
check(W.L["Lit campfires"] == "Lit campfires" and W.L["never translated"] == "never translated", "English is the default")

-- ── task 5: motion stays within bounds ─────────────────────────────────────
draws("the empty list", function() UI:Show("list") end)
check(UI.frame.shown and UI.views.list.shown and UI.views.list.empty.text:find("first warm spot", 1, true), "an empty list explains itself and invites")
check(UI.title.text == "Lit campfires" and UI.back.shown == false, "the list is the home view")
do -- the filter chips sit side by side: each starts after the one before it ends, and the row fits the window
	local chips, edge = UI.views.list.chips, UI.PAD
	for i, chip in ipairs(chips) do
		check(chip.point[2] == edge and chip.w >= #chip.label.text * 5.5 + 22, "chip " .. i .. " starts where the last one ended and holds its label")
		edge = edge + chip.w + 6
	end
	check(edge <= UI.W - UI.PAD + 6, "the chips fit the window: " .. edge)
end

local ana = announce("Ana Lima", { x = 0.501, tier = 2, n = 4, objs = { W.TENT, W.REPAIR }, note = "tent | here",
	people = { { name = "Ana Lima", class = 9 }, { name = "Caio Nunes", class = 7 }, { name = "Bia Rocha", class = 0 } } })
draws("a camp", function() UI:Show("camp", "Ana Lima") end)
local ring = UI.ring
check(ring.seats[1].shown and ring.seats[1].alpha == 0 and next(Motion.arriving) ~= nil, "people start clear and arrive")
local worst, biggest = 1, 1
for _ = 1, 600 do
	S.now = S.now + 0.1
	S.frame(0.1)
	for _, f in ipairs(S.frames) do
		worst, biggest = math.min(worst, f.scale or 1), math.max(biggest, f.scale or 1)
	end
end
check(next(Motion.arriving) == nil and next(Motion.moving) == nil and ring.seats[1].alpha == 1 and ring.seats[1].scale == 1,
	"after arriving, everyone is whole and in place")
check(worst >= 0.4 and biggest <= 1, "a minute of animation: every scale stayed within 0.4..1 (" .. worst .. ".." .. biggest .. ")")
check(ring.flame.tex.coords and ring.flame.tex.coords[2] <= 1, "the flame steps through its sheet")
W.db.lessMotion = true
UI:Show("list"); UI:Show("camp", "Ana Lima")
S.now = S.now + 0.05; S.frame(0.05)
check(ring.seats[1].scale == 1, "less motion: arrivals are fades only")
W.db.lessMotion = false

-- ── task 6: the views ──────────────────────────────────────────────────────
check(UI.title.text == "Ana Lima's camp" and UI.sub.text:find("Durotar", 1, true) and UI.sub.text:find("Journeyman", 1, true), "the camp's header")
check(ring.seats[1].crown.shown and ring.seats[2].crown.shown == false, "the owner wears the flame")
check(ring.seats[3].label.text == "BR" and ring.seats[3].icon.shown == false, "an unknown class falls back to initials")
ring.seats[3]:SetPerson({ name = "\195\129vila \195\141ris", class = 0 })
check(ring.seats[3].label.text == "\195\129\195\141", "initials are whole letters, accents included")
UI:Render()
check(ring.seats[4].label.text == "you" and ring.seats[5].shown == false, "an empty seat marked 'you' is the invitation")
check(ring.slots[1].icon.texture == "icon279978" and ring.slots[3].dash.shown and ring.slots[5].shown and ring.slots[6].shown == false,
	"the tier's five slots: two taken, three open")
check(ring.more.text == "and 1 more around the fire", "the count the owner announced beyond the names: " .. ring.more.text)
check(ring.flame.tex.texture:find("flame$") and not UI.views.camp.objs.text:find("Violet", 1, true), "an ordinary fire")
ana.flame = 1; UI:Render()
check(ring.flame.tex.texture:find("flame%-violet$") and ring.glow.tex.color[3] > 0.9 and UI.views.camp.objs.text:find("Violet flames", 1, true),
	"violet flames: the fire, its light and a line saying why")
ana.flame = 0; UI:Render()
check(ring.flame.tex.texture:find("flame$"), "and back")
check(UI.views.camp.note.text == "\"tent || here\"", "the owner's note is escaped")
check(UI.views.camp.objs.text:find("Camp Tent", 1, true) and UI.views.camp.objs.text:find("3 of 5 places open", 1, true), "what the camp offers")
check(UI.views.camp.other.label.text == "Ask for an invite", "copy unknown: the invite is on offer")
S.copy = 9; ana.zuid = 9; UI:Render()
check(UI.views.camp.other.label.text == "Back to the list", "same copy: no invite needed")
ana.zuid = 3; UI:Render()
check(UI.views.camp.hint.text:find("another copy of the zone", 1, true), "another copy: the view says so")
S.take()
UI.views.camp.other:Click()
check(S.take("Whisper")[1].payload == "C2|I|Ana Lima" and S.printed[#S.printed]:find("Asked Ana Lima", 1, true), "asking for the invite whispers the owner")
UI.views.camp.go:Click()
check(S.waypoint and S.waypoint.map == 1411 and S.waypoint.x == 0.501, "Go there sets the game's waypoint")
S.bags[W.OBJECTS[4][1]] = 1; ana.zuid = 9; UI:Render()
check(UI.views.camp.hint.text:find("Your Sharpening Wheel fits here", 1, true), "an object in my bags that the camp lacks")

for i = 1, 11 do announce("Owner " .. i, { x = 0.5 + i * 0.01, map = i > 9 and 1412 or 1411, zuid = i == 2 and 3 or 0 }) end
draws("a list of 12", function() UI:Show("list") end)
local v = UI.views.list
check(#v.list.items == 12 and v.list.rows[1].shown and v.list.rows[7].shown and v.list.thumb.shown, "twelve camps in seven rows, with a scroll thumb")
check(v.list.rows[1].title.text == "Ana Lima's camp" and v.list.rows[1].sub.text:find("5 yd away", 1, true), "nearest first, with the distance")
v.list.scripts.OnMouseWheel(v.list, -1)
check(v.list.offset == 1 and v.list.rows[1].title.text ~= "Ana Lima's camp", "the wheel scrolls")
local otherRow
for _, camp in ipairs(v.list.items) do if camp.owner == "Owner 2" then otherRow = camp end end
check(otherRow.other == true and v.list.items[#v.list.items].zone == "Mulgore", "other copies are flagged; other zones come last")
UI.filter = "repair"; UI:Render()
check(#v.list.items == 1, "the repairs filter")
UI.filter = "tent"; UI:Render()
v.list.rows[1]:Click()
check(UI.view == "camp" and UI.sel == "Ana Lima" and UI.back.shown, "clicking a row opens its circle")
UI.back:Click()
UI.filter = "all"

draws("set up a camp", function() UI:Show("build") end)
local b = UI.views.build
check(b.lines[2][1].text == "Basic Campfire Kit" and b.lines[2][2].text:find("needs Simple Wood", 1, true), "the checklist: no kit, no wood")
S.bags[W.KITS[1]] = 2; S.bags[W.WOOD[2][1]] = 3; UI:Render()
check(b.lines[2][2].text:find("2 in your bags", 1, true) and b.lines[3][2].text:find("craftable: 3 Star Wood", 1, true), "kits and wood in the bags")
check(b.lines[6][1].text:find("Sharpening Wheel", 1, true) and b.lines[8][1].text:find("Open your Cooking window", 1, true), "my objects, and cooking still unknown")
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", W.KITS[2] + 1000000)
UI:Render()
check(UI.tier == 2 and UI.sub.text:find("Journeyman campfire lit", 1, true) and b.tiers[2].on, "lighting a kit preselects its tier")
check(S.printed[#S.printed]:find("has not been announced", 1, true), "and the chat says it has not been announced")
b.tiers[3]:Click()
check(UI.tier == 3, "the player can correct the tier")
-- the Light button: a secure button owned by UIParent, aimed at the chosen tier's kit, never touched in combat
check(not (UI.light and UI.light.shown) and b.lightText.text == "No Expert kit in your bags.", "no kit of that tier: no button, and the view says why")
b.tiers[1]:Click()
local light = UI.light
check(light and light.shown and light.template == "SecureActionButtonTemplate" and light.parent == UIParent
	and light.attributes.type == "item" and light.attributes.item == "item:" .. W.KITS[1] and light.label.text == "Light the Basic campfire",
	"a kit in the bags: one click uses it")
check(light.point[2] == UIParent and light.point[4] == 300 and b.lightText.text == "", "it sits over its place in the window without being anchored to it")
S.bags[W.KITS[3]] = 1
S.combat = true
S.fire("PLAYER_REGEN_DISABLED")
b.tiers[3]:Click()
check(light.shown == false and light.attributes.item == "item:" .. W.KITS[1] and b.lightText.text == "You are in combat.", "combat hides it and nothing about it changes until combat ends")
S.combat = false
S.fire("PLAYER_REGEN_ENABLED")
check(light.shown and light.attributes.item == "item:" .. W.KITS[3], "after combat it comes back, aimed at the tier chosen meanwhile")
UI:Show("list")
check(light.shown == false, "it leaves with the view")
UI:Show("build")

-- with the game's word on the fire, the lower half follows the state instead of asking
local near = {}
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return near[id] end }
W.lit, W.db.lit, UI.tierTouched = nil, nil, nil
S.bags[W.KITS[3]] = nil
UI:Render()
check(light.shown and light.attributes.item == "item:" .. W.KITS[1] and b.tiers[1].shown == false and b.tierLabel.text == ""
	and b.go.disabled and b.go.label.text == "Light a campfire first", "no fire near, one kind of kit: just the Light button, and no announcing yet")
b.go:Click()
check(Camps:Get("Chehul Costa") == nil and #S.take() == 0, "the disabled Announce does nothing")
S.bags[W.KITS[2]] = 1
UI:Render()
check(UI.tier == 1 and b.tiers[1].shown and b.tiers[2].shown and b.tiers[3].shown == false and b.tierLabel.text == "Which kit to light",
	"two kinds of kit in the bags: a choice between those two only")
S.bags[W.KITS[1]] = nil; S.bags[W.KITS[2]] = nil
UI:Render()
check(light.shown == false and b.lightText.text == "No campfire kit in your bags.", "no kit at all")
S.bags[W.KITS[1]] = 2
near[W.AURA.NEARBY] = {}
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", W.KITS[2] + 1000000)
UI:Render()
check(UI.tier == 2 and b.tiers[1].shown == false and b.tiers[2].shown == false and light.shown == false and b.lightSlot.shown == false
	and b.tierLabel.text == "Journeyman campfire: 5 places for camp objects" and not b.go.disabled and W.db.lit.tier == 2,
	"I lit a Journeyman kit and stand by it: the tier is known, nothing to choose, nothing to light")
W.lit = nil
UI:Render()
check(b.tierLabel.text == "Which campfire is this?" and b.tiers[1].shown and b.tiers[3].shown and light.shown == false,
	"a fire the addon did not see lit: it asks which one")
S.fire("ADDON_LOADED", "Warmth")
check(W.lit and W.lit.tier == 2, "the fire I lit survives a /reload")
near[W.AURA.NEARBY] = nil
S.advance(10)
check(W.lit == nil and W.db.lit == nil, "and is forgotten when it goes out")
C_UnitAuras = nil
-- the clock above jumped a minute at once, so those ticks also marked Ana's fire "not here": back to how it was
ana.gone, ana.notHere = nil, nil
S.bags[W.KITS[3]] = 1
UI.tier = 3
UI:Render()
b.input.text = "come sit"
function b.input:GetText() return self.text end
S.take()
b.go:Click()
local sent = S.take("Realm")
check(#sent == 1 and sent[1].payload:find("|3|1|0||Chehul Costa~j|come sit", 1, true) and UI.view == "camp" and UI.sel == "Chehul Costa",
	"Announce sends the camp and opens my circle: " .. tostring(sent[1] and sent[1].payload))
check(UI.title.text == "Your camp" and UI.views.camp.other.label.text == "End announce", "my own camp")
check(UI.views.camp.hint.text:find("the fire alone gives no benefits", 1, true) and not UI.views.camp.hint.text:find("may end them", 1, true),
	"a fire with no camp object: the view says it gives nothing")
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return (id == W.AURA.BENEFITS or id == W.AURA.NEARBY) and {} or nil end }
UI:Render()
check(UI.views.camp.hint.text:find("may end them", 1, true), "and warns a player who already carries Camp Benefits")
C_UnitAuras = nil
UI.views.camp.other:Click()
check(Camps:Get("Chehul Costa") == nil and UI.view == "list" and S.take("Realm")[1].payload == "C2|X", "ending it tells the network and returns to the list")

-- ── task 7: pins, toast, questions, options, entry ─────────────────────────
WorldMapFrame.shown = true
S.shownMap = 1411
UI.Pins:RefreshWorld()
local function shownPins(list) local n = 0; for _, p in ipairs(list) do if p.shown then n = n + 1 end end; return n end
check(shownPins(UI.Pins.world) == 10, "one pin per camp of the zone shown: " .. shownPins(UI.Pins.world))
check(UI.Pins.world[1].point[4] == 501 and UI.Pins.world[1].point[5] == -300 and UI.Pins.world[1].count.text == 4, "placed by map position, with the head count")
S.shownMap = 1414
UI.Pins:RefreshWorld()
check(shownPins(UI.Pins.world) == 12, "the continent shows every camp of its zones: " .. shownPins(UI.Pins.world))
S.shownMap = 1412
UI.Pins:RefreshWorld()
check(shownPins(UI.Pins.world) == 2, "another zone shows only its own")
W.db.pins = false
UI.Pins:RefreshWorld(); UI.Pins:RefreshMini()
check(shownPins(UI.Pins.world) == 0 and shownPins(UI.Pins.mini) == 0, "pins can be turned off")
W.db.pins = true
local dx, dy, rim = UI.Pins.MinimapOffset(100, 0, 200, 70)
check(dx == 0 and dy == 35 and not rim, "minimap: 100 yards north at a 200 yard radius is half way up")
dx, dy, rim = UI.Pins.MinimapOffset(0, 600, 200, 70)
check(math.abs(dx - 64.4) < 0.01 and dy == 0 and rim, "beyond the radius the pin waits on the rim")
check(UI.Pins.MinimapOffset(0, 1500, 200, 70) == nil, "and beyond 1000 yards it is not shown")
dx, dy = UI.Pins.MinimapOffset(0, -100, 200, 70, math.pi / 2)
check(math.abs(dx) < 0.001 and math.abs(dy - 35) < 0.001, "a rotating minimap: facing west, a camp to the west is up")
UI.Pins:RefreshMini()
check(shownPins(UI.Pins.mini) == 10 and UI.Pins.mini[1].point[4] ~= nil, "minimap pins for the camps of my map")
UI.Pins.world[1].scripts.OnEnter(UI.Pins.world[1])
check(#S.tooltip >= 2, "a pin's tooltip")

check(UI.toast and UI.toast.shown, "the camps announced above already raised the toast")
UI.toast:Hide()
announce("New Fire", { map = 1412 })
check(not (UI.toast and UI.toast.shown), "a campfire in another zone: no toast")
W.db.toast = false
announce("Quiet Fire", {})
check(not (UI.toast and UI.toast.shown), "toasts can be turned off")
W.db.toast = true
announce("Near Fire", { note = "soup's on" })
check(UI.toast.shown and UI.toast.title.text == "A campfire in Durotar" and UI.toast.line.text == "Near Fire: soup's on", "a campfire in my zone: the toast")
check(W.db.consent == nil and not (UI.prompt and UI.prompt.shown), "nobody asked about circles yet")
S.take()
S.advance(10); for _ = 1, 10 do S.now = S.now + 0.1; S.frame(0.1) end
check(UI.toast.shown == false, "it leaves by itself")
check(UI.prompt and UI.prompt.shown and UI.prompt.title.text == "Appear in circles?" and #S.take() == 0, "by an announced fire: the one question, nothing sent")
S.handler("C2|I|Chehul Costa", "Caio Nunes", "WHISPER") -- no camp of mine: ignored
UI.prompt.no:Click()
check(W.db.consent == false and UI.prompt.shown == false, "the answer is stored")
S.advance(30)
check(#S.take() == 0 and UI.prompt.shown == false, "no: never asked again, nothing sent")
W.db.consent = nil
W.Net:Announce(1, "")
S.take()
S.handler("C2|I|Chehul Costa", "Caio Nunes", "WHISPER")
check(UI.prompt.shown and UI.prompt.title.text == "Caio Nunes wants to come to your fire", "an invite request asks the owner")
UI.prompt.yes:Click()
check(S.invited == "Caio Nunes", "accepting invites them")

check(S.registered and S.category.name == "Warmth" and #UI.options.checks == 5, "the options live in the game's AddOns tab")
UI.options.checks[1]:Click()
check(W.db.consent == true, "the consent switch")
UI.options.checks[5]:Click()
check(W.db.lessMotion == true, "the less-motion switch")
W.db.lessMotion = false

local toc = io.open("Warmth.toc"):read("*a")
for fn in toc:gmatch("AddonCompartmentFunc%a*: (%S+)") do check(type(_G[fn]) == "function", "the toc names " .. fn .. ", which exists") end
for path in toc:gmatch("\n([%w/_%.%-]+%.lua)") do check(io.open(path), "the toc lists " .. path .. ", which exists") end
UI.frame.shown = false
Warmth_OnCompartmentClick("Warmth", "LeftButton")
check(UI.frame.shown, "the native button opens the window")
Warmth_OnCompartmentClick("Warmth", "RightButton")
check(UI.view == "build", "right click goes to setting up")
draws("the native button's tooltip", function() Warmth_OnCompartmentEnter("Warmth", UIParent) end)
SlashCmdList.WARMTH("")
check(UI.frame.shown == false, "/warmth toggles")
for owner in pairs(Camps.all) do Camps:End(owner) end
S.take()
SlashCmdList.WARMTH("demo")
check(#Camps:List() == 3 and UI.view == "list" and #S.take() == 0, "/warmth demo: three camps here, nothing sent")
draws("the demo's big circle", function() UI:Show("camp", "Lia Velha") end)
check(ring.seats[9].shown and ring.seats[10].label.text == "you" and ring.more.text == "and 5 more around the fire" and ring.slots[10].shown,
	"nine seats, the invitation, the rest as a count, ten slots")
W.db.consent = true
S.advance(30)
check(#S.take() == 0 and select(2, W.Net:RequestInvite("Lia Velha")) == "demo", "a demo camp never receives a whisper")
check(not (UI.toast and UI.toast.shown), "and the demo raises no toast")
SlashCmdList.WARMTH("clear")
check(#Camps:List() == 0, "/warmth clear")
SlashCmdList.WARMTH("options")
check(S.openedOptions, "/warmth options")

-- the probe: off until asked, records to WarmthDB only
check(W.Probe.on == false and W.db.probe == nil, "the probe is off and has written nothing")
S.take()
SlashCmdList.WARMTH("probe")
check(W.Probe.on and #W.db.probe.api > 30 and #W.db.probe.items == 42 and W.db.probe.items[1]:find("kit1", 1, true), "starting it snapshots the APIs and the 42 camp items")
SlashCmdList.WARMTH("probe lit the basic kit")
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", W.KITS[1] + 1000000)
S.fire("CHAT_MSG_SYSTEM", "You feel cozy.")
S.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "g", 5)
local log = table.concat(W.db.probe.log, "\n")
check(log:find(">>> lit the basic kit", 1, true) and log:find("spell=1279981", 1, true) and log:find("You feel cozy.", 1, true) and not log:find("spell=5", 1, true),
	"marks, my casts and system lines are recorded; other units are not")
SlashCmdList.WARMTH("probe")
check(W.Probe.on == false and W.db.probe.seconds ~= nil and #S.take() == 0 and S.printed[#S.printed]:find("lines recorded", 1, true), "stopping keeps the recording; the probe sent nothing")

-- ptBR end to end
S.locale = "ptBR"
local S2 = dofile("tools/wowstub.lua")
S2.locale = "ptBR"
local W2 = S2.load("Core/", "UI/")
S2.fire("ADDON_LOADED", "Warmth"); S2.fire("PLAYER_LOGIN")
W2.UI:Show("list")
check(W2.UI.title.text == "Fogueiras acesas", "the window in Portuguese")

S.done("ui")
