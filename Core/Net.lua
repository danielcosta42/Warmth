--=============================================================================
-- Warmth on the ChehulNet mesh.
--
-- What leaves this client, and when (the consent rules of the spec, section 2):
--   * an announce: only when the player clicks Announce; its repeats ride on that click and die with the session;
--   * presence in someone's circle: only after the one-time "yes" (W.db.consent == true);
--   * an invite request: only when the player clicks it;
--   * a vendor of camp materials the player opened and the addon's table lacks: later, never on the spot, and only
--     with W.db.shareVendors on (on by default, a switch in the options).
-- Only the announce travels the realm bus (with relay). Presence and invite requests go to the owner by whisper,
-- and presence also to guild and group, where it costs nothing.
--
-- A relayed sender (dist "RELAY") is CLAIMED, not verified: good for a pin, never for authority. Presence and
-- invite requests are taken only from authentic paths.
--=============================================================================
local _, W = ...
local Net = {}
W.Net = Net

Net.PREFIX = "ChehulCamp"
Net.ANNOUNCE_GAP, Net.BEAT, Net.PRESENCE_GAP, Net.INVITE_GAP = 20, 240, 120, 120
Net.OWNER_NEAR = 60    -- yards: the owner still tends the fire
Net.FRESH      = 360   -- seconds: an owner heard within this is whispered to

local lastAnnounce, lastBeat = -1e9, -1e9
local lastPresence, lastInviteTo, lastInviteFrom = {}, {}, {}
Net.tried = {} -- [whisper target] = GetTime() until which its "No player named" line is ours

local function Mesh() return _G.ChehulMesh end

-- The owner's own view of the camp, as the announce carries it.
local function Fields(camp)
	local people = W.Camps:People(camp)
	local list = {}
	for i, p in ipairs(people) do list[i] = { name = p.name, class = p.class } end
	camp.flame = (W.HasAura(W.AURA.VIOLET) == true) and 1 or 0 -- read when I announce: I am by my fire then
	return { map = camp.map, x = camp.x, y = camp.y, zuid = camp.zuid, tier = camp.tier, flame = camp.flame, n = #people,
		age = (time() - camp.at) / 60, objs = W.Camps:Objects(camp), people = list, note = camp.note }
end

local function Broadcast(payload)
	local mesh = Mesh()
	if not mesh then return false end
	mesh:Guild(Net.PREFIX, payload)
	mesh:Group(Net.PREFIX, payload)
	mesh:Realm(Net.PREFIX, payload, "A", true) -- one key: a newer announce replaces a queued one
	return true
end

-- Announce a campfire where the player stands. Returns the camp, or nil and a reason key.
function Net:Announce(tier, note)
	local map, x, y = W.Position()
	if not map then return nil, "no_position" end
	if not W.SLOTS[tier or 0] then return nil, "bad_tier" end
	if W.FireNearby() == false then return nil, "no_fire" end -- the game says there is no campfire here
	if GetTime() - lastAnnounce < self.ANNOUNCE_GAP then return nil, "too_soon" end
	if not Mesh() then return nil, "no_network" end
	W.Camps:End(W.me) -- a new click is a new camp: nobody and nothing carries over from the last place
	local camp = W.Camps:Announce(W.me, { map = map, x = x, y = y, zuid = W.MyCopy(map), tier = tier,
		n = 1, age = 0, objs = {}, people = {}, note = W.Wire.CleanNote(note) })
	if not camp then return nil, "full" end
	lastAnnounce, lastBeat = GetTime(), GetTime()
	W.Camps:Join(W.me, W.me, W.MyClassIndex(), W.Watch:ObjectAt(camp))
	Broadcast(W.Wire.Announce(Fields(camp)))
	self:Extras()
	return camp
end

-- The repeat of an announce the player already made: only while they are still by the fire.
function Net:Heartbeat()
	local camp = W.Camps:Get(W.me)
	if not camp or GetTime() - lastBeat < self.BEAT then return false end
	local d = W.Distance(camp)
	if not d or d > self.OWNER_NEAR or W.FireNearby() == false then return false end
	lastBeat = GetTime()
	W.Camps:Join(W.me, W.me, W.MyClassIndex(), W.Watch:ObjectAt(camp))
	local f = Fields(camp)
	camp.last, camp.n, camp.objs = time(), f.n, f.objs
	Broadcast(W.Wire.Announce(f))
	self:Extras()
	return true
end

-- What goes with my announce: the buff objects my camp still lacks (unless I turned asking off) and my warmth
-- level as a host. The same paths as the announce, and no more often.
function Net:Extras()
	local camp, mesh = W.Camps:Get(W.me), Mesh()
	if not (camp and mesh) then return false end
	camp.wants = (W.db.asking ~= false) and W.Social:Wants(camp) or {}
	camp.host = W.Social:MyLevel()
	local payload = W.Wire.Extras(camp.wants, camp.host)
	mesh:Guild(self.PREFIX, payload)
	mesh:Group(self.PREFIX, payload)
	mesh:Realm(self.PREFIX, payload, "E", true)
	W:Fire("CAMPS")
	return true
end

-- "Thank you for the fire": once a day per host, from someone sitting in their circle. It is the player's click.
function Net:Thank(owner)
	local camp, mesh = W.Camps:Get(owner), Mesh()
	if not (camp and mesh) or not W.Social:CanThank(camp) then return false end
	W.Social:MarkThanked(owner)
	local payload = W.Wire.Thank(owner)
	if time() - camp.last <= self.FRESH then
		self:ExpectNotFound(owner)
		mesh:Whisper(self.PREFIX, payload, owner)
	end
	mesh:Guild(self.PREFIX, payload)
	mesh:Group(self.PREFIX, payload)
	return true
end

function Net:End()
	if not W.Camps:Get(W.me) then return end
	W.Camps:End(W.me)
	Broadcast(W.Wire.End())
end

function Net:ExpectNotFound(target)
	local now = GetTime()
	for name, till in pairs(self.tried) do
		if till < now then self.tried[name] = nil end
	end
	self.tried[target] = now + 30
end

-- "I am in <owner>'s circle". Without the player's yes, nothing is sent and nothing is recorded.
-- `now`: the player just placed an object, which is worth telling at once (still one message per camp per 20 s).
function Net:Presence(owner, now)
	local camp = W.Camps:Get(owner)
	if not camp or camp.demo then return false end -- a demo camp (/warmth demo) exists on this client only
	local obj = W.Watch:ObjectAt(camp)
	if owner == W.me then
		return W.Camps:Join(W.me, W.me, W.MyClassIndex(), obj) -- goes out in my next announce
	end
	if W.db.consent ~= true then return false end
	if GetTime() - (lastPresence[owner] or -1e9) < (now and self.ANNOUNCE_GAP or self.PRESENCE_GAP) then return false end
	lastPresence[owner] = GetTime()
	W.Camps:Join(W.me, owner, W.MyClassIndex(), obj)
	W.Social:Visit(camp)
	local mesh, payload = Mesh(), W.Wire.Join(owner, W.MyClassIndex(), obj)
	if not mesh then return false end
	if time() - camp.last <= self.FRESH then -- an owner gone quiet is probably offline: no whisper into the void
		self:ExpectNotFound(owner)
		mesh:Whisper(self.PREFIX, payload, owner)
	end
	mesh:Guild(self.PREFIX, payload)
	mesh:Group(self.PREFIX, payload)
	return true
end

-- Ask the owner for a group invite, to land in their copy of the zone.
function Net:RequestInvite(owner)
	local camp = W.Camps:Get(owner)
	if camp and camp.demo then return false, "demo" end
	if not camp or owner == W.me then return false, "no_camp" end
	if GetTime() - (lastInviteTo[owner] or -1e9) < self.INVITE_GAP then return false, "too_soon" end
	local mesh = Mesh()
	if not mesh then return false, "no_network" end
	lastInviteTo[owner] = GetTime()
	self:ExpectNotFound(owner)
	mesh:Whisper(self.PREFIX, W.Wire.Invite(owner), owner)
	return true
end

-- The owner's click on the request. Inviting needs that click: the game refuses it from a timer.
function Net:AnswerInvite(name, accept)
	if not accept then return end
	local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	if invite then pcall(invite, name) end
end

-- A vendor of camp materials, told to the network: which npc, where it stands, what it sells. Coalesced per npc.
-- It does say that this player was at that vendor at some point; that is why it waits (see GossipVendor).
function Net:ShareVendor(npc)
	local v, mesh = W.Workshop:Vendors()[npc], Mesh()
	if not (v and mesh) then return false end
	local payload = W.Wire.Vendor(npc, v)
	mesh:Guild(self.PREFIX, payload)
	mesh:Realm(self.PREFIX, payload, "V" .. npc, true)
	return true
end

-- Every half hour, at most one vendor this player opened and the table lacks is told (one guild message and one
-- realm item): never at the moment it is opened, never something only heard, and not at all with the option off.
function Net:GossipVendor()
	if W.db.shareVendors == false then return false end
	local npc = W.Workshop:ToTell()
	if not npc or not self:ShareVendor(npc) then return false end
	W.Workshop:Vendors()[npc].tell = nil
	return true
end

-- What this client tells the network's operator about Warmth when asked (a DIAG, answered only to the operator's
-- characters): counts and switches, nothing about where the player is or who they are with. The burn times are
-- how long this player's own campfires lasted, per tier, in seconds: the network measuring what no guide says.
function Net.Diag()
	local camps, mine, heard = 0, 0, 0
	for _ in pairs(W.Camps.all) do camps = camps + 1 end
	for _, v in pairs(W.Workshop:Vendors()) do
		if v.mine then mine = mine + 1 else heard = heard + 1 end
	end
	local burn = W.db.burn or {}
	local function flag(v) return v == true and "1" or (v == false and "0" or "-") end
	return table.concat({ "v=" .. W.VERSION, "camps=" .. camps, "mine=" .. (W.Camps:Get(W.me) and 1 or 0),
		"auto=" .. flag(W.db.auto ~= false), "consent=" .. flag(W.db.consent), "share=" .. flag(W.db.shareVendors ~= false),
		"vend=" .. mine .. "/" .. heard, "burn=" .. (burn[1] or 0) .. "/" .. (burn[2] or 0) .. "/" .. (burn[3] or 0),
		"compass=" .. flag(W.db.compass ~= false), "asking=" .. flag(W.db.asking ~= false), "heat=" .. (W.db.heat and W.db.heat.points or 0) }, ";")
end

local function OnMessage(payload, sender, dist)
	if W.IsSecret(payload, sender, dist) or type(sender) ~= "string" then return end
	local who = W.Short(sender)
	local msg = W.Wire.Decode(payload)
	if not (msg and who) or who == W.me or not W.db then return end
	if msg.kind == "A" then
		-- an owner the codec could not name in a presence or an invite would be a camp nobody can join
		if W.Wire.GoodName(who) then W.Camps:Announce(who, msg) end
	elseif msg.kind == "X" then
		W.Camps:End(who)
	elseif msg.kind == "E" then
		local camp = W.Camps:Get(who) -- the owner's own word about their camp; a claimed owner can only decorate a pin
		if camp then
			local asked = #msg.wants > 0 and table.concat(msg.wants, ",") ~= table.concat(camp.wants or {}, ",")
			camp.wants, camp.host = msg.wants, msg.level
			W:Fire("CAMPS")
			if asked then W:Fire("CAMP_WANTS", camp) end
		end
	elseif msg.kind == "V" then
		-- hearsay is fine for a map marker; only items this client knows as camp materials are kept
		local wanted, items = W.Workshop:Wanted(), {}
		for _, id in ipairs(msg.items) do
			if wanted[id] then items[#items + 1] = id end
		end
		if #items > 0 then W.Workshop:Learn(msg.npc, { name = msg.name, map = msg.map, x = msg.x, y = msg.y, items = items }, false) end
	elseif dist == "RELAY" then
		return -- presence and invite requests rest on who sent them
	elseif msg.kind == "J" then
		W.Camps:Join(who, msg.owner, msg.class, msg.obj)
	elseif msg.kind == "T" then
		-- thanks count only for my own camp, from someone I heard in my circle
		local camp = W.Camps:Get(W.me)
		if msg.owner == W.me and camp and camp.heard[who] then W.Social:Thanked(who) end
	elseif msg.kind == "I" then
		if dist ~= "WHISPER" or msg.owner ~= W.me or not W.Camps:Get(W.me) or not W.db.invites then return end
		if GetTime() - (lastInviteFrom[who] or -1e9) < Net.INVITE_GAP then return end
		lastInviteFrom[who] = GetTime()
		W:Fire("INVITE_REQUEST", who)
	end
end
Net.OnMessage = OnMessage

--------------------------------------------------------------------------------
-- "No player named X" for a name this addon whispered a moment ago stays out of the chat.
--------------------------------------------------------------------------------
local notFound
local function FilterNotFound(_, _, msg)
	if W.IsSecret(msg) or type(msg) ~= "string" or not next(Net.tried) then return false end
	if notFound == nil then
		local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
		notFound = type(fmt) == "string"
			and ("^" .. fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$") or false
	end
	local name = notFound and msg:match(notFound)
	local till = name and Net.tried[name]
	-- kept until it times out: the filter runs once per chat frame showing system messages
	return till ~= nil and GetTime() <= till
end

W:On("LOADED", function()
	local mesh, CN = Mesh(), _G.ChehulNet
	if mesh then
		mesh:Register(Net.PREFIX, OnMessage)
		if mesh.Relayable then mesh:Relayable(Net.PREFIX) end
		if mesh.PeerStore then mesh:PeerStore(function() return W.db and W.db.meshPeers end) end
	end
	if CN and CN.Register then CN:Register("cf", function() return "cfv=" .. W.VERSION end) end
	if CN and CN.RegisterDiag then CN:RegisterDiag("cf", Net.Diag) end
end)
W:On("LOGIN", function()
	C_Timer.NewTicker(1800, function() Net:GossipVendor() end)
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if add then pcall(add, "CHAT_MSG_SYSTEM", FilterNotFound) end
end)
