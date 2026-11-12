--=============================================================================
-- Everything that moves, computed each frame between fixed bounds.
--
-- There is no AnimationGroup here on purpose: on the Forever client a looping Scale animation accumulates and the
-- region grows until it covers the screen (seen in the prototype). A sine or an eased 0..1 cannot run away.
--
--   Breathe(region, speed, apply)   apply(s), s in 0..1, while the region is visible (a glow's alpha)
--   Flipbook(texture, frames, fps)  steps a horizontal sheet
--   Place(frame, parent, x, y)      the frame's home (centre offset); Arrive needs it
--   Arrive(frame, delay)            pops in at its home: small and clear to full size
--   Anchor(frame, point, rel, relPoint, x, y)   a frame's resting point; Enter and Leave need it
--   Enter(frame, dy)                fades in while sliding dy pixels into its resting point
--   Leave(frame, onDone)            fades out
--
-- With "less motion" on (W.db.lessMotion) only the fades remain.
--=============================================================================
local _, W = ...
local Motion = { breathing = {}, books = {}, arriving = {}, moving = {} }
W.UI.Motion = Motion

local ARRIVE, ENTER, LEAVE = 0.45, 0.32, 0.5

local function Less() return W.db and W.db.lessMotion end
local function EaseOut(p) return 1 - (1 - p) ^ 3 end

function Motion.Breathe(region, speed, apply)
	local list = Motion.breathing
	list[#list + 1] = { region = region, speed = speed, phase = #list * 1.7, apply = apply }
end

function Motion.Flipbook(texture, frames, fps)
	local list = Motion.books
	list[#list + 1] = { texture = texture, frames = frames, fps = fps, phase = #list * 3, shown = -1 }
	texture:SetTexCoord(0, 1 / frames, 0, 1)
end

function Motion.Place(frame, parent, x, y)
	frame.home, frame.homeX, frame.homeY = parent, x, y
	local a = Motion.arriving[frame]
	if a then
		a.x, a.y = x, y -- its place changed while it was still arriving
		return
	end
	frame:SetScale(1)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", parent, "CENTER", x, y)
end

function Motion.Arrive(frame, delay)
	frame:SetAlpha(0)
	Motion.arriving[frame] = { t0 = GetTime() + (delay or 0), parent = frame.home, x = frame.homeX, y = frame.homeY }
end

-- Stops an arrival and leaves the frame whole (a seat reused for something that does not arrive).
function Motion.Settle(frame)
	Motion.arriving[frame] = nil
	frame:SetScale(1)
	frame:SetAlpha(1)
end

function Motion.Anchor(frame, point, rel, relPoint, x, y)
	frame.rest = { point, rel, relPoint, x or 0, y or 0 }
	frame:ClearAllPoints()
	frame:SetPoint(point, rel, relPoint, x or 0, y or 0)
end

function Motion.Enter(frame, dy)
	frame:Show()
	frame:SetAlpha(0)
	Motion.moving[frame] = { t0 = GetTime(), dur = ENTER, dy = Less() and 0 or (dy or 0) }
end

function Motion.Leave(frame, onDone)
	Motion.moving[frame] = { t0 = GetTime(), dur = LEAVE, dy = 0, leaving = true, onDone = onDone }
end

function Motion.Tick(now)
	local less = Less()
	for _, b in ipairs(Motion.breathing) do
		if b.region:IsVisible() then b.apply((math.sin(now * b.speed + b.phase) + 1) / 2) end
	end
	for _, b in ipairs(Motion.books) do
		if b.texture:IsVisible() then
			local i = less and 0 or math.floor(now * b.fps + b.phase) % b.frames
			if i ~= b.shown then
				b.shown = i
				b.texture:SetTexCoord(i / b.frames, (i + 1) / b.frames, 0, 1)
			end
		end
	end
	for frame, a in pairs(Motion.arriving) do
		local p = math.min(1, math.max(0, (now - a.t0) / ARRIVE))
		local k = less and 1 or (0.4 + 0.6 * EaseOut(p))
		frame:SetAlpha(p)
		frame:SetScale(k)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", a.parent, "CENTER", a.x / k, a.y / k) -- an offset is measured in the frame's own scale
		if p >= 1 then Motion.arriving[frame] = nil end
	end
	for frame, m in pairs(Motion.moving) do
		local p = math.min(1, math.max(0, (now - m.t0) / m.dur))
		frame:SetAlpha(m.leaving and (1 - p) or p)
		local r = frame.rest
		if r and m.dy ~= 0 then
			frame:ClearAllPoints()
			frame:SetPoint(r[1], r[2], r[3], r[4], r[5] - m.dy * (1 - EaseOut(p)))
		end
		if p >= 1 then
			Motion.moving[frame] = nil
			if m.leaving then frame:Hide() end
			if m.onDone then m.onDone() end
		end
	end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function() Motion.Tick(GetTime()) end)
