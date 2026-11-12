-- The core (Core/) under a simulated client: wire format, camp state, network rules, watchers.
--   luajit tools/core.lua        (from the repository root)
local S = dofile("tools/wowstub.lua")
local check = S.check
WarmthDB = { consent = false }
local W = S.load("Core/")
S.fire("ADDON_LOADED", "Warmth")
S.fire("PLAYER_LOGIN")

-- ── task 1: namespace, saved variables, network identity ───────────────────
check(Warmth == W and W.VERSION == "0.1.0" and W.me == "Chehul Costa", "namespace, version and the Forever name")
check(W.db.toast == true and W.db.pins == true and W.db.invites == true and W.db.lessMotion == false, "defaults fill a fresh database")
check(W.db.consent == false and type(W.db.meshPeers) == "table", "a saved answer survives the defaults")
check(S.prefix == "ChehulCamp" and S.relayable == "ChehulCamp" and S.tag == "cf" and S.caps() == "cfv=0.1.0", "one prefix, relayable, node tag cf")
check(S.peerStore() == W.db.meshPeers, "the mesh saves its peers in WarmthDB")
W.db.consent = nil

-- ── task 2: data, wire, camps ──────────────────────────────────────────────
check(#W.OBJECTS == 35 and W.OBJECTS[W.TENT][2] == "Camp Tent" and W.OBJECTS[W.REPAIR][2] == "Repair Bot", "35 objects with stable indexes")
local Wire, Camps = W.Wire, W.Camps
local fields = { map = 1411, x = 0.501, y = 0.5, zuid = 77, tier = 2, n = 3, age = 41.7, objs = { W.TENT, W.REPAIR },
	people = { { name = "Ana Lima", class = 9 }, { name = "Caio Nunes", class = 7 } }, note = " tent | repair \n" }
local payload = Wire.Announce(fields)
check(payload == "C2|A|1411|5010|5000|77|2|3|41|16,11|Ana Lima~j;Caio Nunes~h|tent   repair", "an announce on the wire: " .. payload)
local msg = Wire.Decode(payload)
check(msg and msg.kind == "A" and msg.x == 0.501 and msg.zuid == 77 and msg.tier == 2 and msg.n == 3 and msg.age == 41 and msg.objs[2] == W.REPAIR
	and msg.people[2].name == "Caio Nunes" and msg.people[2].class == 7 and msg.note == "tent   repair", "and back")
local j = Wire.Decode(Wire.Join("Ana Lima", 9, W.TENT))
check(j and j.kind == "J" and j.owner == "Ana Lima" and j.class == 9 and j.obj == W.TENT, "presence round trip")
check(Wire.Decode(Wire.End()).kind == "X" and Wire.Decode(Wire.Invite("Ana Lima")).owner == "Ana Lima", "end and invite round trip")

-- Review Focus 2: forged or truncated payloads are dropped
for _, bad in ipairs({ "C1|A|1411|1|1|0|1|1|0|||x", "C2|A|1411|1|1|0|1|1|0||", "C2|A|0|1|1|0|1|1|0|||x", "C2|A|1411|10001|1|0|1|1|0|||x",
	"C2|A|1411|1|1|0|4|1|0|||x", "C2|A|1411|1|1|0|1|41|0|||x", "C2|A|1411|1|1|0|1|1|0|36||x", "C2|A|1411|1|1|0|1|1|0|1,2,3,4||x",
	"C2|A|1411|1|1|0|1|1|0||Bad;Name~b|x", "C2|A|1411|1|1|0|1|1|0||" .. ("n"):rep(41) .. "~b|x", "C2|A|1e3|1|1|0|1|1|0|||x",
	"C2|A|99999999999|1|1|0|1|1|0|||x", "C2|A|1411|1|1|0|1|1|1441|||x", "C2|A|1411|1|1|0|1|1|||x",
	"C2|J|Ana|b", "C2|J|Ana|bb|1", "C2|J|Ana|b|99", "C2|J||b|1", "C2|X|extra", "C2|I|",
	"C2|Q", "", "C2", ("C2|A|1411|1|1|0|1|1|0|||"):rep(60) }) do
	check(Wire.Decode(bad) == nil, "dropped: " .. bad:sub(1, 50))
end
check(#Wire.Decode("C2|A|1411|1|1|0|1|1|0|||" .. ("z"):rep(200)).note == 80, "a long note is cut to 80")
check(Wire.CleanNote(("a"):rep(79) .. "\195\167\195\163") == ("a"):rep(79), "and never in the middle of an accented letter")
check(Wire.CleanNote(("a"):rep(78) .. "\195\167z") == ("a"):rep(78) .. "\195\167", "a whole letter that fits stays")

-- Review Focus 3: a full circle with long names still fits one message and keeps every object
local crowd = { map = 1411, x = 0.5, y = 0.5, zuid = 4000000000 % 2147483647, tier = 3, n = 40, objs = {}, people = {}, note = ("n"):rep(80) }
for i = 1, 10 do crowd.objs[i] = i end
for i = 1, 40 do crowd.people[i] = { name = ("Player With A Long Name %02d"):format(i), class = 13 } end
local big = Wire.Announce(crowd)
local back = Wire.Decode(big)
check(#big <= 240 and back and #back.objs == 10 and #back.people >= 1 and #back.people < 9 and back.n == 40,
	"a crowded announce is " .. #big .. " bytes, all objects, fewer names")

local ana, isNew = Camps:Announce("Ana Lima", msg)
check(ana and isNew and Camps:Get("Ana Lima") == ana, "an announce becomes a camp")
check(time() - ana.at == 41 * 60, "lit when the owner says, not when this client first heard")
local people = Camps:People(ana)
check(#people == 2 and people[1].name == "Ana Lima" and people[1].class == 9 and Camps:Count(ana) == 3, "the roster, owner first; the count is what the owner said")
check(Camps:Join("Bia Rocha", "Ana Lima", 2, 1) and #Camps:People(ana) == 3 and Camps:Has(ana, 1) and #Camps:Objects(ana) == 3, "someone heard directly joins, with the object")
check(not Camps:Join("Bia Rocha", "Nobody", 2, 1), "no circle to join at an unknown camp")
check(Camps:OtherCopy(ana) == nil, "copy unknown on my side: nothing claimed")
S.copy = 77
check(Camps:OtherCopy(ana) == false, "same copy")
S.copy = 12
check(Camps:OtherCopy(ana) == true, "another copy")
local d = W.Distance(ana)
check(d and math.abs(d - 5) < 0.01, "distance in yards: " .. tostring(d))
Camps:Announce("Rui Novo", { map = 1411, x = 0.6, y = 0.5, zuid = 12, tier = 1, n = 1, objs = {}, people = {}, note = "" })
Camps:Announce("Zed Far", { map = 1412, x = 0.5, y = 0.5, zuid = 0, tier = 1, n = 1, objs = {}, people = {}, note = "" })
local list = Camps:List()
check(list[1].owner == "Rui Novo" and list[2].owner == "Ana Lima" and list[3].owner == "Zed Far" and list[3].zone == "Mulgore",
	"my map first, my copy before other copies, then other zones by name")
S.advance(361)
Camps:Announce("Ana Lima", msg)
check(#Camps:People(ana) == 2, "a person not heard for 360 s leaves the circle")
S.advance(721)
check(#Camps:List() == 0, "a camp with no news for 720 s is gone")
for i = 1, 105 do Camps:Announce("Owner " .. i, msg) end
check(#Camps:List() == 100, "at most 100 camps")
local full = Camps:Get("Owner 1")
for i = 1, 45 do Camps:Join("Guest " .. i, "Owner 1", 1, 0) end
check(#Camps:People(full) <= 43, "at most 40 people heard directly in a circle")
for i = 1, 105 do Camps:End("Owner " .. i) end

-- ── task 3: network and watchers ───────────────────────────────────────────
S.take()
S.copy = 12
-- Review Focus 1: no position (instance)
local keep = S.pos
S.pos = nil
local none, why = W.Net:Announce(1, "x")
check(none == nil and why == "no_position" and #S.take() == 0 and W.Distance(msg) == nil, "no position: the announce is refused, nothing is sent")
S.pos = keep

-- lighting a kit and placing an object fill the screen only
local lit
W:On("LIT", function(tier) lit = tier end)
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.KITS[2] + 1000000)
check(lit == 2 and W.lit.tier == 2 and #S.take() == 0, "lighting a kit is noticed and sends nothing")
S.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", W.KITS[1] + 1000000)
check(W.lit.tier == 2, "someone else's cast is not mine")

local mine = W.Net:Announce(2, "need a tent")
local sent = S.take()
check(mine and mine.owner == "Chehul Costa" and mine.zuid == 12 and #sent == 3 and sent[1].bus == "Guild" and sent[2].bus == "Group"
	and sent[3].bus == "Realm" and sent[3].relay == true, "announce goes to guild, group and the realm with relay")
check(sent[3].payload == "C2|A|1411|5000|5000|12|2|1|0||Chehul Costa~j|need a tent", "with me in my own circle: " .. sent[3].payload)
check(select(2, W.Net:Announce(2, "again")) == "too_soon" and #S.take() == 0, "no second announce within 20 s")

-- the owner hears presence and invite requests only from authentic paths
S.handler(Wire.Join("Chehul Costa", 7, W.TENT), "Caio Nunes-Realm", "WHISPER")
S.handler(Wire.Join("Chehul Costa", 7, W.TENT), "Fake Relay", "RELAY")
check(#Camps:People(mine) == 2 and Camps:Has(mine, W.TENT), "a whispered presence joins my circle; a relayed one does not")
local asked = {}
W:On("INVITE_REQUEST", function(name) asked[#asked + 1] = name end)
S.handler(Wire.Invite("Chehul Costa"), "Caio Nunes", "WHISPER")
S.handler(Wire.Invite("Chehul Costa"), "Caio Nunes", "WHISPER")
S.handler(Wire.Invite("Chehul Costa"), "Fake Relay", "RELAY")
S.handler(Wire.Invite("Someone Else"), "Bia Rocha", "WHISPER")
check(#asked == 1 and asked[1] == "Caio Nunes", "one invite request per person per 2 minutes, whispered to me only")
W.db.invites = false
S.advance(130)
S.handler(Wire.Invite("Chehul Costa"), "Caio Nunes", "WHISPER")
check(#asked == 1, "invite requests can be turned off")
W.db.invites = true
W.Net:AnswerInvite("Caio Nunes", true)
check(S.invited == "Caio Nunes", "accepting invites the player")

-- heartbeat: every 240 s, only while by the fire, carrying the circle
S.take()
S.advance(120) -- 250 s since the announce; the ticker ran
local beat = S.take("Realm")
check(#beat == 1 and beat[1].payload:find("|2|4|" .. W.TENT .. "|Chehul Costa~j;Caio Nunes~h|need a tent", 1, true), "the repeat carries people and objects: " .. tostring(beat[1] and beat[1].payload))
S.pos = { map = 1411, x = 0.6, y = 0.5 } -- 500 yards away
S.advance(300)
check(#S.take("Realm") == 0, "away from the fire, the announce stops repeating")
-- Review Focus 4: the abandoned camp disappears here too
S.advance(500)
check(Camps:Get("Chehul Costa") == nil or #Camps:List() == 0, "and the abandoned camp expires")
S.pos = keep

-- Review Focus 5: presence needs the yes
local needed = 0
W:On("CONSENT_NEEDED", function() needed = needed + 1 end)
S.handler(payload, "Ana Lima", "RELAY") -- Ana's camp, 5 yards away, copy 77
S.copy = 77
S.take()
S.advance(30)
check(needed == 1 and #S.take() == 0 and not Camps:Get("Ana Lima").heard["Chehul Costa"], "never asked: one question, no presence sent")
W.db.consent = false
S.advance(30)
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.OBJECTS[4][1] + 1000000)
check(W.placed.obj == 4 and #S.take() == 0 and needed == 1, "answered no: placing an object by her fire still sends nothing")
W.db.consent = true
S.advance(10)
sent = S.take()
check(#sent == 3 and sent[1].bus == "Whisper" and sent[1].target == "Ana Lima" and sent[1].payload == "C2|J|Ana Lima|j|4"
	and sent[2].bus == "Guild" and sent[3].bus == "Group", "answered yes: presence goes to the owner, guild and group, never the realm")
check(Camps:Get("Ana Lima").heard["Chehul Costa"].obj == 4, "and I am in the circle here")
S.advance(60)
check(#S.take() == 0, "presence repeats every 120 s, not every tick")
S.copy = 12
S.advance(120)
check(#S.take() == 0, "known to be in another copy: I am not at that fire")
S.copy = 77
check(W.Net:RequestInvite("Ana Lima") and S.take("Whisper")[1].payload == "C2|I|Ana Lima", "an invite request is a whisper to the owner")
check(select(2, W.Net:RequestInvite("Ana Lima")) == "too_soon", "one per camp per 2 minutes")
-- Review Focus 4, the visitor's side: an owner gone quiet gets no more whispers
S.advance(400)
-- an object stays where it was put: at another camp I arrive with empty hands
S.handler("C2|A|1411|6000|5000|77|1|1|0|||", "Far Camp", "RELAY")
S.pos = { map = 1411, x = 0.6, y = 0.5 }
S.advance(150)
S.take()
S.advance(130)
local far = S.take("Whisper")
check(#far == 1 and far[1].target == "Far Camp" and far[1].payload == "C2|J|Far Camp|j|0" and not Camps:Has(Camps:Get("Far Camp"), 4),
	"the object I placed at Ana's fire does not follow me to another camp")
S.pos = keep
S.handler("C2|X", "Far Camp", "RELAY")

S.handler("C2|A|1411|5010|5000|77|2|3|0|16,11|Ana Lima~j|", "Ana Lima", "RELAY")
S.advance(370)
S.take()
S.advance(130)
local late = S.take()
check(#late > 0 and late[1].bus ~= "Whisper", "no whisper to an owner not heard for 6 minutes")
S.handler(Wire.End(), "Ana Lima", "RELAY")
check(Camps:Get("Ana Lima") == nil, "the owner ends the camp")

-- "No player named" for a name we whispered stays out of the chat
W.Net:ExpectNotFound("Ana Lima")
local filter = S.filters.CHAT_MSG_SYSTEM
check(filter(nil, nil, "No player named 'Ana Lima' is currently playing.") == true
	and filter(nil, nil, "No player named 'Ana Lima' is currently playing.") == true
	and filter(nil, nil, "No player named 'Other' is currently playing.") == false, "our not-found line is hidden in every chat frame; others pass")
S.advance(31)
check(filter(nil, nil, "No player named 'Ana Lima' is currently playing.") == false, "and only for half a minute")

-- hostile input
S.handler("C2|A|1411|5000|5000|0|1|1|0|||", "Bad;Owner", "RELAY")
S.handler("C2|A|1411|5000|5000|0|1|1|0|||", ("L"):rep(45), "RELAY")
check(Camps:Get("Bad;Owner") == nil and Camps:Get(("L"):rep(45)) == nil, "an owner nobody could name in a presence is not a camp")
S.handler("C2|A|1411|5000|5000|0|1|1|0|||", "Late Echo", "RELAY")
S.handler("C2|X", "Late Echo", "RELAY")
S.handler("C2|A|1411|5000|5000|0|1|1|0|||", "Late Echo", "RELAY")
check(Camps:Get("Late Echo") == nil, "a relayed announce that arrives right after its End does not bring the camp back")
S.advance(16)
S.handler("C2|A|1411|5000|5000|0|1|1|0|||", "Late Echo", "RELAY")
check(Camps:Get("Late Echo") ~= nil, "but the owner can announce again a moment later")
S.handler("C2|X", "Late Echo", "RELAY")
for i = 1, 100 do S.handler("C2|A|1411|5000|5000|0|1|1|0|||", "Flood " .. i, "RELAY") end
check(#Camps:List() == 100 and W.Net:Announce(1, "room for me") ~= nil, "a hundred camps from the network never block my own announce")
W.Net:End()
for i = 1, 100 do S.handler("C2|X", "Flood " .. i, "RELAY") end
-- a pile of camps on one spot costs one presence, not a hundred
for i = 1, 5 do S.handler("C2|A|1411|5000|5000|77|1|1|0|||", "Pile " .. i, "RELAY") end
S.take()
S.advance(100)
check(#S.take("Whisper") == 1, "five camps on the same spot: I am at one fire, and say so once")
for i = 1, 5 do S.handler("C2|X", "Pile " .. i, "RELAY") end

-- cooking snapshot
function GetTradeSkillLine() return "Cooking" end
function GetNumTradeSkills() return 3 end
function GetTradeSkillInfo(i) return ({ "Meats", "Charred Wolf Meat", "Spice Bread" })[i], ({ "header", "easy", "easy" })[i], ({ 0, 4, 0 })[i] end
S.fire("TRADE_SKILL_SHOW")
check(W.cooking and W.cooking.ready == 1 and W.cooking.names[1] == "Charred Wolf Meat", "the Cooking window tells what can be made now")

-- the same through the modern API, which is what Forever has
GetTradeSkillLine, GetNumTradeSkills, GetTradeSkillInfo = nil, nil, nil
W.cooking = nil
C_TradeSkillUI = {
	GetBaseProfessionInfo = function() return { professionName = "Cooking" } end,
	GetAllRecipeIDs = function() return { 1, 2, 3 } end,
	GetRecipeInfo = function(id) return ({ { name = "Spice Bread", learned = true, numAvailable = 2 }, { name = "Unknown", learned = false, numAvailable = 9 },
		{ name = "Smoked Boar", learned = true, numAvailable = 0 } })[id] end,
}
S.fire("TRADE_SKILL_LIST_UPDATE")
check(W.cooking and W.cooking.ready == 1 and W.cooking.names[1] == "Spice Bread", "Cooking through C_TradeSkillUI: learned recipes with materials")
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "Blacksmithing" } end
W.cooking = nil
S.fire("TRADE_SKILL_SHOW")
check(W.cooking == nil, "another profession's window is not Cooking")

-- the game's own word on whether a fire is here ("Campfire Nearby", measured with the probe)
check(W.FireNearby() == nil, "no aura API: the client cannot tell, and distance alone decides (everything above)")
local auras = {}
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
check(W.FireNearby() == false and select(2, W.Net:Announce(1, "x")) == "no_fire" and #S.take() == 0, "no campfire near: nothing to announce")
auras[W.AURA.NEARBY] = { spellId = W.AURA.NEARBY }
S.advance(30)
local lit = W.Net:Announce(1, "real fire")
check(W.FireNearby() == true and lit ~= nil, "with the game's Campfire Nearby aura the announce goes")
S.take()
auras[W.AURA.NEARBY] = nil
local out = 0
W:On("FIRE_OUT", function() out = out + 1 end)
S.advance(10)
check(Camps:Get("Chehul Costa") ~= nil and out == 0, "one tick without the aura is not yet a fire gone out")
S.advance(10)
check(Camps:Get("Chehul Costa") == nil and out == 1 and S.take("Realm")[1].payload == "C2|X", "my fire went out: the announce ends by itself and the network is told")
S.handler("C2|A|1411|5000|5000|77|1|1|0|||", "Ghost Camp", "RELAY")
S.take()
S.advance(30)
local ghost = Camps:Get("Ghost Camp")
check(ghost.notHere == true and Camps:OtherCopy(ghost) == true and #S.take() == 0, "standing at an announced camp with no fire: it is marked not here, and I am not in its circle")
auras[W.AURA.NEARBY] = { spellId = W.AURA.NEARBY }
S.advance(130)
check(ghost.notHere == nil and S.take("Whisper")[1].payload:find("^C2|J|Ghost Camp|j|"), "the fire shows up: the mark clears and presence resumes")
-- violet flames (the Violet Dust toy): seen by whoever stands at the fire, and carried by the owner's announce
auras[W.AURA.VIOLET] = { spellId = W.AURA.VIOLET }
S.advance(10)
check(ghost.violetSeen == true and Camps:Violet(ghost), "standing by a fire with violet flames: this client sees it")
auras[W.AURA.VIOLET] = nil
S.advance(10)
check(not Camps:Violet(ghost), "and sees it end")
auras[W.AURA.VIOLET] = { spellId = W.AURA.VIOLET }
S.handler("C2|X", "Ghost Camp", "RELAY")
S.advance(30)
W.Net:Announce(2, "purple")
local violet = S.take("Realm")[1].payload
check(violet:find("|2v|1|0|", 1, true) and violet:find("Chehul Costa~j|purple", 1, true) and Wire.Decode(violet).flame == 1 and Wire.Decode(violet).tier == 2, "the owner's announce carries the flag: " .. violet)
check(Wire.Decode("C2|A|1411|1|1|0|2|1|0|||x").flame == 0 and Wire.Decode("C2|A|1411|1|1|0|2vz|1|0|||x").tier == 2
	and Wire.Decode("C2|A|1411|1|1|0|2V|1|0|||x") == nil and Wire.Decode("C2|A|1411|1|1|0|v2|1|0|||x") == nil, "no flag, an unknown future flag, and malformed tiers")
S.handler("C2|A|1411|5500|5000|77|1v|1|0|||", "Purple Camp", "RELAY")
check(Camps:Violet(Camps:Get("Purple Camp")), "a far camp is violet on the owner's word")
S.handler("C2|X", "Purple Camp", "RELAY")
W.Net:End()
C_UnitAuras = nil

check(W.Esc("a|Hb\n") == "a||Hb?", "network text is escaped before display")
S.done("core")
