AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local trailColor = Color(255, 255, 255, 255)
local bounceSounds = {
	"weapons/physcannon/energy_bounce1.wav",
	"weapons/physcannon/energy_bounce2.wav"
}

local function IsDamageTarget(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayer() then return ent:Alive() end
	return ent:IsNPC()
end

function ENT:Initialize()
	self:SetModel(self.Model)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInitSphere(self.BallRadius or 10, "metal_bouncy")
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetTrigger(true)
	self:DrawShadow(false)

	self.MaxTargetHits = self.HG_MaxTargetHits or self.BallTargetHitsToExpire or 3
	self.Damage = self.HG_Damage or self.BallDamage or 220
	self.MinBounceSpeed = self.HG_MinBounceSpeed or self.BallMinBounceSpeed or 900
	self.DieTime = CurTime() + (self.HG_Duration or self.BallDuration or 4)
	self.TargetHits = 0
	self.LastDamageAt = 0
	self.HitCooldowns = {}
	self.LastPos = self:GetPos()

	self.Trail = util.SpriteTrail(self, 0, trailColor, true, 12, 0, 0.2, 1, "sprites/combineball_trail_black_1.vmt")

	self.WhizLoop = CreateSound(self, "weapons/physcannon/energy_sing_loop4.wav")
	if self.WhizLoop then
		self.WhizLoop:PlayEx(0.7, 100)
	end

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableDrag(false)
		phys:EnableGravity(false)
		phys:SetMass(self.HG_Mass or self.BallMass or 150)
		phys:SetMaterial("metal_bouncy")
		phys:SetDamping(0, 0)
	end
end

function ENT:Launch(velocity)
	self.InitialVelocity = velocity
	self.LastPos = self:GetPos()
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocityInstantaneous(velocity)
	end
end

function ENT:DealTargetDamage(target)
	if not IsDamageTarget(target) then return end
	if target == self:GetOwner() then return end

	local now = CurTime()
	local nextAllowed = self.HitCooldowns[target]
	if nextAllowed and nextAllowed > now then return end
	self.HitCooldowns[target] = now + 0.2

	local dmg = DamageInfo()
	dmg:SetDamage(self.Damage)
	dmg:SetDamageType(bit.bor(DMG_DISSOLVE, DMG_SHOCK, DMG_BLAST))
	dmg:SetInflictor(self)
	dmg:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
	dmg:SetDamagePosition(target:WorldSpaceCenter())
	target:TakeDamageInfo(dmg)

	self.TargetHits = (self.TargetHits or 0) + 1
	if self.TargetHits >= self.MaxTargetHits then
		self:ExplodeAndRemove()
	end
end

function ENT:PhysicsCollide(data, phys)
	if not IsValid(self) then return end

	local hit = data.HitEntity
	if IsDamageTarget(hit) then
		self:DealTargetDamage(hit)
		return
	end

	if data.Speed > 80 then
		self:EmitSound(bounceSounds[math.random(1, #bounceSounds)], 78, math.random(96, 104), 0.7, CHAN_ITEM)
		local bounceFx = EffectData()
		bounceFx:SetOrigin(data.HitPos)
		util.Effect("cball_bounce", bounceFx, true, true)
	end

	if IsValid(phys) and data.HitNormal then
		local inVel = data.OurOldVelocity
		if inVel and inVel:LengthSqr() > 1 then
			local reflected = inVel - 2 * inVel:Dot(data.HitNormal) * data.HitNormal
			local speed = math.max(reflected:Length(), self.MinBounceSpeed)
			phys:SetVelocityInstantaneous(reflected:GetNormalized() * speed)
		end
	end
end

function ENT:StartTouch(ent)
	self:DealTargetDamage(ent)
end

function ENT:ExplodeAndRemove()
	if self.Exploded then return end
	self.Exploded = true

	local effectData = EffectData()
	effectData:SetOrigin(self:GetPos())
	util.Effect("cball_explode", effectData, true, true)

	self:EmitSound("weapons/physcannon/energy_sing_explosion2.wav", 85, 100, 0.8, CHAN_AUTO)
	SafeRemoveEntityDelayed(self, 0)
end

function ENT:Think()
	if CurTime() >= (self.DieTime or 0) then
		self:ExplodeAndRemove()
		return
	end

	local curPos = self:GetPos()
	local lastPos = self.LastPos or curPos
	if lastPos ~= curPos then
		local radius = self.BallRadius or 10
		local hitTrace = util.TraceHull({
			start = lastPos,
			endpos = curPos,
			mins = Vector(-radius, -radius, -radius),
			maxs = Vector(radius, radius, radius),
			filter = {self, self:GetOwner()},
			mask = MASK_SHOT
		})

		if hitTrace.Hit and IsDamageTarget(hitTrace.Entity) then
			self:DealTargetDamage(hitTrace.Entity)
		end
	end
	self.LastPos = curPos

	self:NextThink(CurTime())
	return true
end

function ENT:OnRemove()
	if self.WhizLoop then
		self.WhizLoop:Stop()
		self.WhizLoop = nil
	end

	if IsValid(self.Trail) then
		self.Trail:Remove()
	end
end
