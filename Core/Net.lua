--=============================================================================
-- Warmth on the ChehulNet mesh.
--
-- What leaves this client, and when (the consent rules of the spec, section 2):
--   * an announce: only when the player clicks Announce; its repeats ride on that click and die with the session;
--   * presence in someone's circle: only after the one-time "yes" (W.db.consent == true);
--   * an invite request: only when the player clicks it.
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
	return { map = camp.map, x = camp.x, y = camp.y, zuid = camp.zuid, tier = camp.tier, n = #people,
		objs = W.Camps:Objects(camp), people = list, note = camp.note }
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
	if GetTime() - lastAnnounce < self.ANNOUNCE_GAP then return nil, "too_soon" end
	if not Mesh() then return nil, "no_network" end
	lastAnnounce, lastBeat = GetTime(), GetTime()
	local camp = W.Camps:Announce(W.me, { map = map, x = x, y = y, zuid = W.MyCopy(map), tier = tier,
		n = 1, objs = {}, people = {}, note = W.Wire.CleanNote(note) })
	if not camp then return nil, "full" end
	camp.heard, camp.order = {}, {} -- a new click is a new circle: nobody carries over from the last place
	W.Camps:Join(W.me, W.me, W.MyClassIndex(), W.myObject or 0)
	Broadcast(W.Wire.Announce(Fields(camp)))
	return camp
end

-- The repeat of an announce the player already made: only while they are still by the fire.
function Net:Heartbeat()
	local camp = W.Camps:Get(W.me)
	if not camp or GetTime() - lastBeat < self.BEAT then return false end
	local d = W.Distance(camp)
	if not d or d > self.OWNER_NEAR then return false end
	lastBeat = GetTime()
	W.Camps:Join(W.me, W.me, W.MyClassIndex(), W.myObject or 0)
	local f = Fields(camp)
	camp.last, camp.n, camp.objs = time(), f.n, f.objs
	Broadcast(W.Wire.Announce(f))
	return true
end

function Net:End()
	if not W.Camps:Get(W.me) then return end
	W.Camps:End(W.me)
	Broadcast(W.Wire.End())
end

function Net:ExpectNotFound(target)
	self.tried[target] = GetTime() + 30
end

-- "I am in <owner>'s circle". Without the player's yes, nothing is sent and nothing is recorded.
function Net:Presence(owner)
	local camp = W.Camps:Get(owner)
	if not camp then return false end
	if owner == W.me then
		return W.Camps:Join(W.me, W.me, W.MyClassIndex(), W.myObject or 0) -- goes out in my next announce
	end
	if W.db.consent ~= true then return false end
	if GetTime() - (lastPresence[owner] or -1e9) < self.PRESENCE_GAP then return false end
	lastPresence[owner] = GetTime()
	W.Camps:Join(W.me, owner, W.MyClassIndex(), W.myObject or 0)
	local mesh, payload = Mesh(), W.Wire.Join(owner, W.MyClassIndex(), W.myObject or 0)
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

local function OnMessage(payload, sender, dist)
	if W.IsSecret(payload, sender, dist) or type(sender) ~= "string" then return end
	local who = W.Short(sender)
	local msg = W.Wire.Decode(payload)
	if not (msg and who) or who == W.me or not W.db then return end
	if msg.kind == "A" then
		W.Camps:Announce(who, msg)
	elseif msg.kind == "X" then
		W.Camps:End(who)
	elseif dist == "RELAY" then
		return -- presence and invite requests rest on who sent them
	elseif msg.kind == "J" then
		W.Camps:Join(who, msg.owner, msg.class, msg.obj)
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
	if not till then return false end
	Net.tried[name] = nil
	return GetTime() <= till
end

W:On("LOADED", function()
	local mesh, CN = Mesh(), _G.ChehulNet
	if mesh then
		mesh:Register(Net.PREFIX, OnMessage)
		if mesh.Relayable then mesh:Relayable(Net.PREFIX) end
		if mesh.PeerStore then mesh:PeerStore(function() return W.db and W.db.meshPeers end) end
	end
	if CN and CN.Register then CN:Register("cf", function() return "cfv=" .. W.VERSION end) end
end)
W:On("LOGIN", function()
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if add then pcall(add, "CHAT_MSG_SYSTEM", FilterNotFound) end
end)
