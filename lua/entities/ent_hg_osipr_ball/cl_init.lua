include("shared.lua")

local coreMat = Material("effects/blueflare1.vmt",  "nocull additive")
local ringMat = Material("sprites/combineball_trail_black_1.vmt", "nocull additive")

local SEG_COUNT = 24
local TWO_PI    = math.pi * 2
local COL_RING  = Color(180, 215, 255, 255)
local COL_CORE  = Color(255, 255, 255, 255)
local COL_CORE2 = Color(200, 230, 255, 200)

local function DrawRing(pos, ax1, ax2, radius, width, col)
	local step = TWO_PI / SEG_COUNT
	render.SetMaterial(ringMat)
	for i = 0, SEG_COUNT - 1 do
		local a1 = i * step
		local a2 = (i + 1) * step
		local p1 = pos + ax1 * (math.cos(a1) * radius) + ax2 * (math.sin(a1) * radius)
		local p2 = pos + ax1 * (math.cos(a2) * radius) + ax2 * (math.sin(a2) * radius)
		render.DrawBeam(p1, p2, width, 0, 1, col)
	end
end

function ENT:Draw()
	local pos    = self:GetPos()
	local t      = CurTime()
	local pulse  = 0.88 + math.sin(t * 7.5) * 0.12
	local radius = (self.BallRadius or 10) * 1.05 * pulse

	-- Three rings on orthogonal rotating axes to read as a sphere
	local spinAng = Angle(t * 40, t * 120, t * 60)
	local fwd = spinAng:Forward()
	local rgt = spinAng:Right()
	local up  = spinAng:Up()

	DrawRing(pos, fwd, rgt, radius, 3.5, COL_RING)
	DrawRing(pos, fwd, up,  radius, 3.5, COL_RING)
	DrawRing(pos, rgt, up,  radius, 3.2, Color(160, 200, 255, 190))

	-- Outer glow halo (camera-facing)
	render.SetMaterial(coreMat)
	render.DrawSprite(pos, radius * 3.0 * pulse, radius * 3.0 * pulse, COL_CORE2)

	-- Bright inner core
	render.DrawSprite(pos, radius * 1.4, radius * 1.4, COL_CORE)
end
