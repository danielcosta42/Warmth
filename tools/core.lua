-- The core (Core/) under a simulated client: wire format, camp state, network rules, watchers.
--   luajit tools/core.lua        (from the repository root)
local S = dofile("tools/wowstub.lua")
local check = S.check
-- The owner's extras (message E) ride along with every announce. The checks written before it existed count
-- announces, so they look at the traffic without it; the ones about it set S.extras.
local take = S.take
S.take = function(bus)
	local out = {}
	for _, m in ipairs(take(bus)) do
		if S.extras or not m.payload:find("^C2|E|") then out[#out + 1] = m end
	end
	return out
end
WarmthDB = { consent = false }
local W = S.load("Core/")
S.fire("ADDON_LOADED", "Warmth")
S.fire("PLAYER_LOGIN")
check(W.db.auto == true and W.db.compass == true, "a campfire is announced as it is lit, by default")
W.db.auto = false -- most of this file exercises the manual path

-- ── task 1: namespace, saved variables, network identity ───────────────────
check(Warmth == W and W.VERSION == "0.1.0" and W.me == "Chehul Costa", "namespace, version and the Forever name")
check(W.db.toast == true and W.db.pins == true and W.db.invites == true and W.db.lessMotion == false, "defaults fill a fresh database")
check(W.db.consent == false and type(W.db.meshPeers) == "table", "a saved answer survives the defaults")
check(S.prefix == "ChehulCamp" and S.relayable == "ChehulCamp" and S.tag == "cf" and S.caps() == "cfv=0.1.0", "one prefix, relayable, node tag cf")
check(S.peerStore() == W.db.meshPeers, "the mesh saves its peers in WarmthDB")
check(S.diagTag == "cf" and S.diag() == "v=0.1.0;camps=0;mine=0;auto=0;consent=0;share=1;vend=0/0;burn=0/0/0;compass=1;asking=1;heat=0",
	"what the operator's diagnostic gets from Warmth: " .. S.diag())
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

-- timing my own fire: from the kit's cast until the game's aura drops, only if I stayed by it
local burned
W:On("BURNED", function(tier, seconds) burned = { tier, seconds } end)
auras[W.AURA.NEARBY] = { spellId = W.AURA.NEARBY }
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.KITS[1] + 1000000)
S.advance(600)
check(burned == nil and W.db.burn == nil, "the fire still burns: nothing measured yet")
auras[W.AURA.NEARBY] = nil
S.advance(10)
check(burned and burned[1] == 1 and math.abs(burned[2] - 600) <= 10 and W.db.burn[1] == burned[2], "it went out with me beside it: " .. tostring(burned and burned[2]) .. " s, kept per tier")
burned = nil
auras[W.AURA.NEARBY] = { spellId = W.AURA.NEARBY }
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.KITS[2] + 1000000)
S.advance(100)
S.pos = { map = 1411, x = 0.6, y = 0.5 }
S.advance(20)
auras[W.AURA.NEARBY] = nil
S.advance(20)
check(burned == nil and W.db.burn[2] == nil, "I walked away from it: that is not a measurement")
S.pos = keep

-- the automatic announce: on by default, the network learns of a campfire as it is lit
W.db.auto = true
local auto = 0
W:On("AUTO_ANNOUNCED", function() auto = auto + 1 end)
auras[W.AURA.NEARBY], auras[W.AURA.VIOLET] = nil, nil
S.advance(30)
S.take()
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.KITS[1] + 1000000)
S.advance(2)
check(auto == 0 and #S.take() == 0, "the cast went through but the game shows no fire: nothing is announced")
auras[W.AURA.NEARBY] = { spellId = W.AURA.NEARBY }
S.advance(30)
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.KITS[3] + 1000000)
check(#S.take() == 0, "not in the same instant as the cast")
S.advance(2)
local autoSent = S.take("Realm")
check(auto == 1 and #autoSent == 1 and autoSent[1].payload:find("^C2|A|1411|5000|5000|77|3|1|0|") and Camps:Get("Chehul Costa").tier == 3,
	"a moment later, with the fire there: announced by itself, with the tier of the kit")
W.Net:End()
W.db.auto = false
S.advance(30)
S.take()
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.KITS[1] + 1000000)
S.advance(5)
check(auto == 1 and #S.take() == 0, "turned off in the options: lighting announces nothing")
S.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", W.VIOLET_DUST_SPELL)
check(W.db.violetToy == true, "throwing Violet Dust tells the addon the player owns the toy")
C_UnitAuras = nil

-- ── the Workshop ───────────────────────────────────────────────────────────
local Workshop = W.Workshop
check(W.SKILL[1] == 20 and W.SKILL[2] == 140 and W.SKILL[3] == 300 and W.SKILL[28] == 140 and W.SKILL[29] == 300 and W.SKILL[30] == 20,
	"each object's skill: 20, 140, 300, and Cooking's two start at 140")
check(#Workshop:List() == 0, "no profession reported: nothing to list")
S.profs = { { "Leatherworking", 45, 75, 165 }, { "Skinning", 188, 225, 393 }, { "First Aid", 60, 150, 129 } }
S.known = { [W.RECIPES[W.TENT]] = true, [W.RECIPES[22]] = true }
local schem = {
	[W.RECIPES[W.TENT]] = { { 2318, 5 } }, [W.RECIPES[17]] = { { 2319, 5 }, { 2321, 3 }, { 4470, 2 } },
	[W.RECIPES[22]] = { { 2318, 3 }, { 4470, 2 } }, [W.RECIPES[30]] = { { 1251, 3 }, { 159, 1 } },
}
C_TradeSkillUI = { OpenTradeSkill = function(line) S.opened = line; return true end, GetRecipeSchematic = function(id)
	local slots = {}
	for i, r in ipairs(schem[id] or {}) do slots[i] = { quantityRequired = r[2], reagents = { { itemID = r[1] } } } end
	return { reagentSlotSchematics = slots }
end }
S.bags = { [2318] = 11 }
local by = {}
for _, e in ipairs(Workshop:List()) do by[W.OBJECTS[e.index][2]] = e end
check(by["Camp Tent"].state == "ready" and by["Camp Tent"].can == 2 and Workshop:List()[1].index == W.TENT, "learned, with materials: ready, how many, listed first")
check(by["Camp Chair"].state == "materials" and by["Camp Chair"].reagents[2].item == 4470 and by["Camp Chair"].reagents[2].have == 0, "learned, a material short")
check(by["First Aid Kit"].state == "recipe" and by["Tanning Rack"].state == "skill" and by["Tanning Rack"].need == 140 and by["Tanning Rack"].rank == 45,
	"skill enough but not learned: the recipe; skill short: the skill")
check(by["Mana Well"] == nil and by["Field Guide"].state == "recipe", "another profession's objects are not listed; mine all are")
check(Workshop:Open(165) and S.opened == 165, "opening the profession")

-- vendors: the seed, learning one by opening it, telling the network, hearing others
-- vendors: the table generated from QuestieDB, with what is learned in game laid over it
local count, alliance = 0, 0
for _, v in pairs(W.VENDOR_DATA) do
	count = count + 1
	check(type(v[1]) == "string" and v[2] > 0 and v[3] >= 0 and v[3] <= 10000 and v[4] >= 0 and v[4] <= 10000 and (v[5] == "A" or v[5] == "H" or v[5] == "AH") and #v[6] > 0,
		"a well-formed vendor line: " .. tostring(v[1]))
	if v[5] == "A" then alliance = alliance + 1 end
end
check(count > 300 and alliance > 50, "the generated table: " .. count .. " vendors")
local xen = W.VENDOR_DATA[3400]
check(xen[1] == "Xen'to" and xen[2] == 1454 and math.abs(xen[3] - 5750) < 30 and math.abs(xen[4] - 5314) < 30,
	"it agrees with the vendor measured in game (Xen'to, Orgrimmar 57.50, 53.14)")
check(Workshop:Sellers(4470)[3400] and Workshop:Sellers(4470)[3400].name == "Xen'to", "the Horde's Simple Wood vendors include him")
for npc, v in pairs(W.VENDOR_DATA) do
	if v[5] == "A" then check(Workshop:Sellers(v[6][1])[npc] == nil, "a Horde player is not sent to an Alliance-only vendor") break end
end
check(Workshop:Wanted()[2321] and Workshop:Wanted()[8925], "what vendors sell counts as camp material even before the game says what recipes take")
-- a vendor the table lacks, opened by me: written down, and told later, never on the spot
S.take()
S.npc, S.merchant = "Creature-0-1-1-1-990001-0000", { 4470, 2320, 2321, 9999 }
S.fire("MERCHANT_SHOW")
local trade = Workshop:Vendors()[990001]
check(trade and trade.mine and trade.tell and trade.map == 1411 and #trade.items == 3 and trade.items[3] == 2321,
	"opening a vendor the table lacks writes it down, with only the items that matter")
check(#S.take() == 0 and not W.Net:GossipVendor() and #S.take() == 0, "nothing is sent then, nor in the next minutes: it would say where I am right now")
S.fire("MERCHANT_SHOW")
check(Workshop:Vendors()[990001] == trade, "the same vendor again changes nothing")
S.advance(601)
local told = S.take()
if #told == 0 then W.Net:GossipVendor(); told = S.take() end
check(#told == 2 and told[1].bus == "Guild" and told[2].bus == "Realm" and told[2].relay == true and told[2].payload == "C2|V|990001|1411|5000|5000|4470,2320,2321|Chehul",
	"ten minutes later the gossip tells who, where and what: " .. tostring(told[2] and told[2].payload))
check(Workshop:Vendors()[990001].tell == nil and not W.Net:GossipVendor() and #S.take() == 0, "once: there is nothing left to tell")
S.pos = { map = 1454, x = 0.5757, y = 0.5290 }
S.npc, S.merchant = "Creature-0-1-1-1-3400-0000", { 4470, 159 }
S.fire("MERCHANT_SHOW")
check(Workshop:Vendors()[3400] == nil, "a vendor the table already has, where the table says, adds nothing")
S.pos = keep
S.npc, S.merchant = "Creature-0-1-1-1-777-0000", { 9999, 8888 }
S.fire("MERCHANT_SHOW")
check(Workshop:Vendors()[777] == nil and #S.take() == 0, "a vendor with nothing for a camp is ignored")
S.advance(6)
local vend, yards = Workshop:Vendor(4470)
check(vend.name == "Chehul" and vend.map == 1411 and yards == 0, "the nearest vendor of an item is the one I am standing at")

-- what the network says is hearsay: it never corrects the table or me, and never outranks a trusted vendor
S.handler("C2|V|990002|1411|5100|5000|2321,159,777777|Far Trader", "Someone Else", "RELAY")
check(Workshop:Vendors()[990002] and #Workshop:Vendors()[990002].items == 2 and not Workshop:Vendors()[990002].mine, "a vendor heard on the network is kept apart, with the items that are camp materials")
S.handler("C2|V|990002|1411|5100|5000|2321|Far Trader", "Someone Else", "RELAY")
check(#Workshop:Vendors()[990002].items == 2, "a shorter list heard later does not erase what was heard")
S.handler("C2|V|3400|1429|100|100|4470|Liar", "Someone Else", "RELAY")
check(Workshop:Vendors()[3400] == nil and Workshop:Sellers(4470)[3400].map == 1454, "a forged message cannot move a vendor the table knows")
S.handler("C2|V|990001|1412|1|1|4470|Liar", "Someone Else", "RELAY")
check(Workshop:Vendors()[990001].map == 1411 and Workshop:Vendors()[990001].name == "Chehul", "nor one I opened myself")
S.handler("C2|V|990003|1411|5001|5000|4470|Fake Wood", "Someone Else", "RELAY")
S.advance(6)
check(Workshop:Vendor(4470).name == "Chehul" and Workshop:Sellers(4470)[990003] == nil, "a forged vendor next to me is not the nearest seller of something trusted vendors sell")
for n = 1, 6 do S.handler("C2|V|" .. (990100 + n) .. "|1411|5000|5000|2840|Bar Seller " .. n, "Someone Else", "RELAY") end
check(W.Sources:Get(2840).kind == "craft", "six forged sellers do not turn a smelted bar into something sold everywhere")
S.handler("C2|V|990005|1429|5000|5000|2321|Elwynn Trader", "Someone Else", "RELAY")
check(Workshop:Vendors()[990005] == nil, "a vendor in the other faction's home is no use")
S.handler("C2|V|990004|1411|5200|5000|2318|Leather Guy", "Someone Else", "RELAY")
S.advance(61)
local guy, _, heardOnly = Workshop:Vendor(2318)
check(guy and guy.name == "Leather Guy" and heardOnly == true, "hearsay is used where no trusted vendor sells the item, and is marked as such")
for _, bad in ipairs({ "C2|V|0|1411|1|1|4470|x", "C2|V|5|1411|10001|1|4470|x", "C2|V|5|1411|1|1||x", "C2|V|5|1411|1|1|abc|x", "C2|V|5|1411|1|1|4470|",
	"C2|V|5|1411|1|1|4470|a|extra", "C2|V|5|1411|1|1|1,2,3,4,5,6,7,8,9,10,11,12,13|x", "C2|V|5|1411|1|1|4470|bad;name" }) do
	check(Wire.Decode(bad) == nil, "dropped: " .. bad)
end
S.handler("C2|V|4001|1411|5000|5000|777777|Nothing Useful", "Someone Else", "RELAY")
check(Workshop:Vendors()[4001] == nil, "a vendor selling nothing this client knows as camp material is not kept")
check(Wire.Vendor(1, { map = 1, x = 0, y = 0, items = { 1 }, name = ("a"):rep(39) .. "\195\167\195\163" }):sub(-39) == ("a"):rep(39),
	"a long vendor name is cut on a whole letter")
S.take()
S.advance(1900)
check(#S.take() == 0, "hearsay is never passed on: the gossip has nothing to say")
-- room for my own vendors whatever the network sends
for n = 1, 150 do S.handler("C2|V|" .. (991000 + n) .. "|1411|5000|5000|2321|Flood " .. n, "Someone Else", "RELAY") end
local heardCount = 0
for _, v in pairs(Workshop:Vendors()) do if not v.mine then heardCount = heardCount + 1 end end
check(heardCount <= Workshop.HEARD_MAX and Workshop:Vendors()[990001] ~= nil, "a flood of hearsay is capped at " .. Workshop.HEARD_MAX .. " and never pushes out what I opened")
S.npc, S.merchant = "Creature-0-1-1-1-990009-0000", { 2321 }
S.fire("MERCHANT_SHOW")
check(Workshop:Vendors()[990009] and Workshop:Vendors()[990009].mine, "and a vendor I open still goes in")
W.db.shareVendors = false
S.advance(1900)
check(#S.take() == 0 and Workshop:Vendors()[990009].tell, "with the option off, nothing I open is told")
W.db.shareVendors = true

-- how to get what nobody sells
local Sources = W.Sources
local function kind(item) return Sources:Get(item).kind end
check(kind(2321) == "vendor" and kind(4470) == "vendor", "threads and wood: a vendor")
check(kind(2840) == "craft" and Sources:Get(2840).profession == "Mining" and Sources:Get(2840).from[1][1] == 2770, "a bar is smelted from its ore")
local ore = Sources:Get(2770)
check(ore.kind == "nodes" and #ore.places == 2, "an ore is mined: the two zones with the most veins, veins before the creatures that carry it")
for _, place in ipairs(ore.places) do check(not Sources.Avoid(place.map), "and never in the other faction's home: " .. place.map) end
check(Sources.Avoid(1429) and Sources.Avoid(1436) and not Sources.Avoid(1411) and not Sources.Avoid(1434), "a Horde player is not sent to Elwynn or Westfall")
local meat = Sources:Get(12037)
check(meat.kind == "mobs" and meat.places[1].creature and meat.places[1].from <= meat.places[1].to, "Mystery Meat: who drops it, at what level, where")
check(kind(2318) == "skin" and kind(10940) ~= "unknown" and kind(6291) == "fish" and kind(273130) == "unknown",
	"leather is skinned, a fish is fished, and a Forever boss part is honestly unknown")
check(kind(2447) == "nodes" and kind(2319) == "skin", "three herb vendors or one leather vendor are a limited stock: gathering or skinning comes first")
check(W.ItemName(2770, "x") == "Copper Ore", "raw materials have a name before the client caches them")
S.bags, S.profs, S.known, C_TradeSkillUI = {}, nil, nil, nil

-- ── what a camp asks for, thanking the host, the guestbook ─────────────────
local Social = W.Social
S.extras = true
for owner in pairs(Camps.all) do Camps:End(owner) end
S.advance(30)
S.take()
local home = W.Net:Announce(2, "")
local out = S.take("Realm")
check(#out == 2 and out[2].payload == "C2|E|16,33,7,1,4|0" and #home.wants == 5 and home.wants[1] == W.TENT,
	"my announce is followed by what the camp lacks, the tent first, as many as there are open places: " .. tostring(out[2] and out[2].payload))
local e = Wire.Decode("C2|E|16,33|3")
check(e.kind == "E" and e.wants[2] == 33 and e.level == 3 and Wire.Decode("C2|E||0").kind == "E", "extras round trip, with nothing asked too")
for _, bad in ipairs({ "C2|E|16|6", "C2|E|99|1", "C2|E|1,2,3,4,5,6,7|1", "C2|E|16", "C2|E|16|1|x", "C2|T|", "C2|T|a|b" }) do
	check(Wire.Decode(bad) == nil, "dropped: " .. bad)
end
W.db.asking = false
W.Net:Extras()
check(S.take("Realm")[1].payload == "C2|E||0" and #home.wants == 0, "asking can be turned off: the camp asks for nothing")
W.db.asking = true

-- a host is thanked: only by someone heard in the circle, once a day each
local thanked = {}
W:On("THANKED", function(who, points, level) thanked[#thanked + 1] = { who, points, level } end)
S.handler("C2|T|Chehul Costa", "Stranger", "WHISPER")
check(#thanked == 0 and W.db.heat.points == 0, "thanks from someone who is not in my circle do not count")
S.handler(Wire.Join("Chehul Costa", 7, 0), "Caio Nunes", "WHISPER")
S.handler("C2|T|Chehul Costa", "Caio Nunes", "RELAY")
check(#thanked == 0, "nor relayed ones, whose sender is only claimed")
S.handler("C2|T|Chehul Costa", "Caio Nunes", "WHISPER")
S.handler("C2|T|Chehul Costa", "Caio Nunes", "WHISPER")
check(#thanked == 1 and thanked[1][1] == "Caio Nunes" and W.db.heat.points == 1, "a guest's thanks count once a day")
for n = 1, 2 do
	S.handler(Wire.Join("Chehul Costa", 1, 0), "Guest " .. n, "WHISPER")
	S.handler("C2|T|Chehul Costa", "Guest " .. n, "WHISPER")
end
check(W.db.heat.points == 3 and Social:MyLevel() == 1 and thanked[3][3] == 1 and Social:Level(9) == 1 and Social:Level(10) == 2 and Social:Level(999) == 5,
	"three thanks make a Kindling host; the steps are 3, 10, 25, 60, 150")
W.Net:Extras()
check(S.take("Realm")[1].payload:find("|1$"), "and the level goes out with the camp")
W.Net:End()

-- a guest: what the camp asks for, thanking, the guestbook
S.take()
W.db.consent = true
S.copy, S.pos = 77, keep
S.handler("C2|A|1411|5010|5000|77|2|1|0|||", "Ana Lima", "RELAY")
local wantsFired = 0
W:On("CAMP_WANTS", function() wantsFired = wantsFired + 1 end)
S.handler("C2|E|16,4|4", "Ana Lima", "RELAY")
S.handler("C2|E|16,4|4", "Ana Lima", "RELAY")
local anaCamp = Camps:Get("Ana Lima")
check(anaCamp.wants[2] == 4 and anaCamp.host == 4 and wantsFired == 1, "a camp's extras: what it asks for and its host's level; the same request again is not news")
check(Social:CanAnswer(anaCamp) == nil, "nothing of mine answers it")
S.bags = { [W.OBJECTS[4][1]] = 1 }
local answer, how = Social:CanAnswer(anaCamp)
check(answer == 4 and how == "bags", "a Sharpening Wheel in my bags does")
S.bags = {}
check(not Social:CanThank(anaCamp) and not W.Net:Thank("Ana Lima"), "I cannot thank a host whose circle I am not in")
local visits = #W.db.guestbook -- the checks above already sat at a few fires
S.advance(130)
S.take()
check(anaCamp.heard["Chehul Costa"] and #W.db.guestbook == visits + 1 and W.db.guestbook[1].owner == "Ana Lima", "sitting at her fire writes the guestbook")
S.advance(130)
check(#W.db.guestbook == visits + 1, "once per camp")
S.take()
check(Social:CanThank(anaCamp) and W.Net:Thank("Ana Lima"), "in her circle, I can thank her")
local thanks = S.take()
check(#thanks == 3 and thanks[1].bus == "Whisper" and thanks[1].target == "Ana Lima" and thanks[1].payload == "C2|T|Ana Lima", "thanks go to the host by whisper, and to guild and group")
check(not Social:CanThank(anaCamp) and not W.Net:Thank("Ana Lima") and #S.take() == 0, "once a day per host")
S.handler("C2|X", "Ana Lima", "RELAY")

-- which of a camp's benefits I would really gain
C_Spell.GetSpellName = function(id) return ({ [2550] = "Cooking", [1126] = "Mark of the Wild", [1243] = "Power Word: Fortitude" })[id] end
C_UnitAuras = { GetAuraDataByIndex = function(_, i) return ({ { name = "Mark of the Wild" }, { name = "Ghost Wolf" } })[i] end,
	GetPlayerAuraBySpellID = function(id) return id == W.AURA.WELCOME and { duration = 60, expirationTime = GetTime() + 45 } or nil end }
check(Social:AlreadyHave(7) == "Mark of the Wild" and Social:AlreadyHave(30) == nil and Social:AlreadyHave(W.TENT) == nil,
	"the Enchanted Lute adds nothing to someone with Mark of the Wild; the First Aid Kit and the tent do")
local left, total = W.AuraLeft(W.AURA.WELCOME)
check(left == 45 and total == 60 and W.AuraLeft(W.AURA.BENEFITS) == nil, "the minute by the fire: seconds left and its length")
C_UnitAuras = nil
S.extras = nil
check(S.diag():find("asking=1;heat=3", 1, true), "the diagnostic reports asking and warmth")

-- pieces placed by someone without Warmth: noted when the player points at them
for owner in pairs(Camps.all) do Camps:End(owner) end
S.advance(30)
S.take()
check(W.Watch:Spot("Camp Tent") == nil, "pointing at a tent away from any camp notes nothing")
local spotCamp = W.Net:Announce(2, "")
S.take()
S.extras = true
check(W.Watch:Spot("Camp Tent") == W.TENT and Camps:Has(spotCamp, W.TENT), "at my camp, the tent under the mouse is noted")
local told = S.take("Realm")
check(#told == 1 and told[1].payload:find("^C2|E|") and not told[1].payload:find("|" .. W.TENT .. ",", 1, true), "and my camp stops asking for it: " .. tostring(told[1] and told[1].payload))
local chair
for i, o in ipairs(W.OBJECTS) do if o[2] == "Camp Chair" then chair = i end end
check(W.Watch:Spot("Chair") == chair and W.Watch:Spot("Chair") == chair and #Camps:Objects(spotCamp) == 2, "the world object's name may drop the item's Camp; twice is once")
check(W.Watch:Spot("Basic Campfire") == nil and W.Watch:Spot("Mailbox") == nil, "other things under the mouse are nothing")
S.extras = nil
W.Net:End()
S.take()

check(W.Esc("a|Hb\n") == "a||Hb?", "network text is escaped before display")
S.done("core")
