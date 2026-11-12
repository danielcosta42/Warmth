--=============================================================================
-- Campfires on the world map (the zone's map and its parents) and on the minimap.
-- A pin is a breathing glow, bigger with more people around the fire; one in another copy of the zone is dimmer.
--=============================================================================
local _, W = ...
local UI = W.UI
local T, Wd, L = UI.T, UI.Widgets, W.L
local Pins = { world = {}, mini = {} }
UI.Pins = Pins

local function Tip(self)
	local camp = self.camp
	if not camp then return end
	local lines = { L["%d by the fire"]:format(W.Camps:Count(camp)) .. "  ·  " .. L[W.TIERS[camp.tier]] .. "  ·  " .. UI.Where(camp) }
	for _, index in ipairs(W.Camps:Objects(camp)) do
		local o = W.OBJECTS[index]
		lines[#lines + 1] = UI.C.mute .. W.ObjectName(index) .. (o[4] and (": " .. L[o[4]]) or "") .. UI.C.r
	end
	if camp.note ~= "" then lines[#lines + 1] = UI.C.ember .. "\"" .. W.Esc(camp.note) .. "\"" .. UI.C.r end
	if W.Camps:OtherCopy(camp) == true then lines[#lines + 1] = UI.C.copy .. L["In another copy of the zone"] .. UI.C.r end
	lines[#lines + 1] = UI.C.mute .. L["Click to see the circle"] .. UI.C.r
	Wd.Tip(self, UI.CampTitle(camp), lines, "ANCHOR_RIGHT")
end

local function Pin(parent, size, withCount)
	local p = CreateFrame("Button", nil, parent)
	p:SetSize(size, size)
	p:SetFrameLevel(parent:GetFrameLevel() + 500)
	p.glow = Wd.Glow(p, size * 2)
	p.glow:SetPoint("CENTER")
	p.flame = Wd.Flame(p, size)
	p.flame:SetPoint("CENTER", 0, size * 0.08)
	if withCount then
		p.badge = Wd.Tex(p, "disc", T.night, 1, "OVERLAY")
		p.badge:SetSize(18, 18)
		p.badge:SetPoint("TOPRIGHT", 6, 4)
		p.count = Wd.Text(p, 10.5, T.ember, "title")
		p.count:SetPoint("CENTER", p.badge, "CENTER")
	end
	p:SetScript("OnEnter", Tip)
	p:SetScript("OnLeave", Wd.HideTip)
	p:SetScript("OnClick", function(self) if self.camp then UI:Show("camp", self.camp.owner) end end)
	return p
end

local function Dress(p, camp)
	local count = W.Camps:Count(camp)
	p.camp = camp
	p.glow.strength = math.min(1, 0.55 + count * 0.08)
	p.glow:SetViolet(W.Camps:Violet(camp))
	p.flame:SetViolet(W.Camps:Violet(camp))
	p:SetAlpha(W.Camps:OtherCopy(camp) == true and 0.55 or 1)
	if p.count then p.count:SetText(count) end
end

-- Where a camp falls on the map being shown (0..1), or nil when it is off that map.
function Pins.OnMap(camp, shown)
	if camp.map == shown then return camp.x, camp.y end
	if not (C_Map and C_Map.GetMapPosFromWorldPos) then return nil end
	local n, w, continent = W.World(camp.map, camp.x, camp.y)
	if not n then return nil end
	local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(n, w), shown)
	if not (ok and pos) then return nil end
	local x, y = pos:GetXY()
	if not x or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return x, y
end

function Pins:RefreshWorld()
	local wm = _G.WorldMapFrame
	if not (wm and wm.GetCanvas and wm.GetMapID and wm:IsShown()) then return end
	local canvas, shown = wm:GetCanvas(), wm:GetMapID()
	local i = 0
	if canvas and shown and W.db.pins then
		local w, h = canvas:GetWidth(), canvas:GetHeight()
		for _, camp in ipairs(W.Camps:List()) do
			local x, y = Pins.OnMap(camp, shown)
			if x then
				i = i + 1
				local p = self.world[i] or Pin(canvas, 34, true)
				self.world[i] = p
				Dress(p, camp)
				p:ClearAllPoints()
				p:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
				p:Show()
			end
		end
	end
	for j = i + 1, #self.world do self.world[j]:Hide() end
end

-- Minimap radius in yards per zoom level, outdoors. ponytail: indoors the minimap covers less ground and the pin
-- sits a little too far out; add the indoor table if camps in caves matter.
local RADIUS = { [0] = 233.3, 200, 166.7, 133.3, 100, 66.7 }
Pins.EDGE = 1000 -- yards: beyond the minimap but within this, the pin waits on the rim, pointing the way

-- Pixel offset from the minimap's centre for a camp `north` and `east` yards away; nil when too far to show.
-- Second result: true when it was pulled to the rim.
function Pins.MinimapOffset(north, east, radius, half, facing)
	local dist = math.sqrt(north * north + east * east)
	if dist > Pins.EDGE then return nil end
	if facing then -- a rotating minimap keeps the player's heading up
		local s, c = math.sin(facing), math.cos(facing)
		north, east = north * c - east * s, east * c + north * s
	end
	local rim = dist > radius * 0.92
	local k = (rim and (radius * 0.92 / dist) or 1) / radius * half
	return east * k, north * k, rim
end

function Pins:RefreshMini()
	local i = 0
	local map, x, y = W.Position()
	local mini = _G.Minimap
	if map and mini and W.db.pins then
		local pn, pw = W.World(map, x, y)
		local radius = RADIUS[(mini.GetZoom and mini:GetZoom()) or 0] or RADIUS[0]
		local facing = (GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing and GetPlayerFacing()) or nil
		for _, camp in ipairs(pn and W.Camps:List() or {}) do
			local cn, cw = W.World(camp.map, camp.x, camp.y)
			if camp.map == map and cn then
				local dx, dy, rim = Pins.MinimapOffset(cn - pn, pw - cw, radius, mini:GetWidth() / 2, facing)
				if dx then
					i = i + 1
					local p = self.mini[i] or Pin(mini, 18, false)
					self.mini[i] = p
					Dress(p, camp)
					if rim then p:SetAlpha(p:GetAlpha() * 0.7) end
					p:ClearAllPoints()
					p:SetPoint("CENTER", mini, "CENTER", dx, dy)
					p:Show()
				end
			end
		end
	end
	for j = i + 1, #self.mini do self.mini[j]:Hide() end
end

local hooked
local function HookMap()
	local wm = _G.WorldMapFrame
	if hooked or not wm then return end
	hooked = true
	wm:HookScript("OnShow", function() Pins:RefreshWorld() end)
	if wm.OnMapChanged then hooksecurefunc(wm, "OnMapChanged", function() Pins:RefreshWorld() end) end
end

W:On("CAMPS", function() Pins:RefreshWorld() end)
W:On("LOGIN", function()
	HookMap()
	local ticker, acc, beats = CreateFrame("Frame"), 0, 0
	ticker:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 0.25 then return end
		acc, beats = 0, beats + 1
		HookMap() -- the world map may load after login
		Pins:RefreshMini()
		if beats % 8 == 0 then Pins:RefreshWorld() end -- a camp that expired leaves an open map too
	end)
end)
