-- Expanding energy ring when ent_hg_osipr_ball explodes
-- Replicates the HL2 combine ball shockwave ring

local ringMat  = Material("sprites/combineball_trail_black_1.vmt", "nocull additive")
local glowMat  = Material("effects/blueflare1.vmt", "nocull additive")

local SEG_COUNT = 36
local TWO_PI    = math.pi * 2

function EFFECT:Init(data)
	self.Origin    = data:GetOrigin()
	self.StartTime = CurTime()
	self.Duration  = 0.42
	self.MaxRadius = 120
	self.RingWidth = 18
end

function EFFECT:Think()
	return CurTime() < self.StartTime + self.Duration
end

local function DrawRingPlane(origin, ax1, ax2, radius, width, col)
	local step = TWO_PI / SEG_COUNT
	for i = 0, SEG_COUNT - 1 do
		local a1 = i * step
		local a2 = (i + 1) * step
		local p1 = origin + ax1 * (math.cos(a1) * radius) + ax2 * (math.sin(a1) * radius)
		local p2 = origin + ax1 * (math.cos(a2) * radius) + ax2 * (math.sin(a2) * radius)
		render.DrawBeam(p1, p2, width, 0, 1, col)
	end
end

function EFFECT:Render()
	local frac = (CurTime() - self.StartTime) / self.Duration
	if frac >= 1 then return end

	local alpha  = (1 - frac) ^ 0.6 * 210
	local radius = Lerp(frac ^ 0.5, 4, self.MaxRadius)
	local width  = self.RingWidth * (1 - frac * 0.65)

	local col    = Color(190, 220, 255, alpha)
	local colFaint = Color(160, 200, 255, alpha * 0.6)
	local origin = self.Origin

	-- Three rings on all axes so it's visible from any camera angle
	render.SetMaterial(ringMat)
	DrawRingPlane(origin, Vector(1,0,0), Vector(0,1,0), radius, width, col)        -- XY (top-down)
	DrawRingPlane(origin, Vector(1,0,0), Vector(0,0,1), radius, width * 0.8, colFaint) -- XZ (front)
	DrawRingPlane(origin, Vector(0,1,0), Vector(0,0,1), radius, width * 0.8, colFaint) -- YZ (side)

	-- Central flash glow at start
	if frac < 0.25 then
		local flashAlpha = (1 - frac / 0.25) * 180
		render.SetMaterial(glowMat)
		render.DrawSprite(origin, radius * 1.6, radius * 1.6, Color(220, 235, 255, flashAlpha))
	end
end
