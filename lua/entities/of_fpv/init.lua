-- 改自 Pac_187 的代码
ENT.RocketSpeed = 22000
ENT.RocketFuel  = 120

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

function ENT:Initialize()
 
    self.Entity:SetModel( "models/kamik/hunter_scanner.mdl" )
    self.Entity:PhysicsInit( SOLID_VPHYSICS )
    self.Entity:SetMoveType(  MOVETYPE_VPHYSICS )   
    self.Entity:SetSolid( SOLID_VPHYSICS )
	self.SpawnTime = CurTime()
 
    self.PhysObj = self.Entity:GetPhysicsObject()
    if (self.PhysObj:IsValid()) then
		self.PhysObj:EnableGravity( false )
		self.PhysObj:EnableDrag( false ) 
		self.PhysObj:SetMass(30)
        self.PhysObj:Wake()
    end
		
	if not self.Sound then
		self.Sound = CreateSound(self, "offpv.loop")
		self.Sound:Play()
		self.Sound:ChangeVolume(550)
	end
	util.PrecacheSound( "offpv.explosion" )
	util.PrecacheModel( "models/kamik/gibs/scanner_gib01.mdl" )
	util.PrecacheModel( "models/kamik/gibs/scanner_gib02.mdl" )
	util.PrecacheModel( "models/kamik/gibs/scanner_gib03.mdl" )
	util.PrecacheModel( "models/kamik/gibs/scanner_gib04.mdl" )
	util.PrecacheModel( "models/kamik/gibs/scanner_gib05.mdl" )
	
	self.NoFuel = CurTime() + self.RocketFuel
	self.Dead =  false
	self.Attack = false
	self.ownerDead = false
   
end

function ENT:Think()
	if self.NoFuel !=nil and CurTime() > self.NoFuel and self.Dead == false then
		self.Dead = true
		self.Entity:EmitSound("offpv.explosion")
		self:Explosion()
		self.Entity:Remove()
	end
	if self.Attack == true and self.Dead == false then
		self.Dead = true
		self.Entity:EmitSound("offpv.explosion")
		self:Explosion()
		self.Entity:Remove()
	end
	if not self.Entity:GetOwner():Alive() then
		self.ownerDead = true
	end
end

function ENT:OnTakeDamage()
	if self.Dead == false then
		self.Dead = true
		self.Entity:EmitSound("offpv.explosion")
		self:Explosion()
		self.Entity:Remove()
	end
end
 
function ENT:PhysicsUpdate( phys )
	local ply = self.Entity:GetOwner()

    local forward = self.Entity:GetForward()
    local up = self.Entity:GetUp()
    local direction = (forward + up * 0.3):GetNormalized()
    
    local ang = direction * self.RocketSpeed
	local upang = self.Entity:GetUp() * math.Rand(700,1000) * (math.sin(CurTime()*10))
	local rightang = self.Entity:GetRight() * math.Rand(700,1000) * (math.cos(CurTime()*10))
	local force
	if self.SpawnTime + 0.5 < CurTime() then
		force = ang + upang + rightang
	else
		force = ang
	end
	phys:ApplyForceCenter(force)
	if self.ownerDead == false then
		self.Entity:SetAngles( ply:GetAimVector():Angle() )
	end
end

local CRAP_GIBS = {
    "models/kamik/gibs/scanner_gib01.mdl",
    "models/kamik/gibs/scanner_gib02.mdl", 
    "models/kamik/gibs/scanner_gib03.mdl",
    "models/kamik/gibs/scanner_gib04.mdl",
    "models/kamik/gibs/scanner_gib05.mdl"
}

function ENT:myGibs()
    for i, model in ipairs(CRAP_GIBS) do  -- 遍历CRAP_GIBS中的所有模型
        local gibs = ents.Create("prop_physics")
        gibs:SetModel(model)  -- 使用CRAP_GIBS中的模型
        gibs:SetPos(self.Entity:GetPos() + Vector(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)))
        gibs:Spawn()
        gibs:Activate()
        gibs:Ignite(math.random(6, 12), 0)
        gibs:Fire("kill", "", math.random(6, 12))
        
        local physObj = gibs:GetPhysicsObject()
        physObj:SetMass(50)

		local zfire = ents.Create( "env_fire_trail" )
		zfire:SetPos( gibs:GetPos() )
		zfire:SetParent( gibs )
		zfire:Spawn()
		zfire:Activate()
    end
end

function ENT:Explosion()
 	util.BlastDamage( self.Entity, self.Entity:GetOwner(), self.Entity:GetPos(), 380, 1500 )
	local pos = self.Entity:GetPos()
	local angle = Angle(0, 0, 0)
	ParticleEffect("svl_explosion", pos, angle)
	
	local explo = ents.Create( "env_explosion" )
	explo:SetOwner( self.Owner )
	explo:SetPos( self.Entity:GetPos() )
	explo:SetKeyValue( "iMagnitude", "50" )
	explo:SetKeyValue( "iRadiusOverride", "400" )
	explo:Spawn()
	explo:Activate()
	explo:Fire( "Explode", "", 0 )

	local physExplo = ents.Create( "env_physexplosion" )
	physExplo:SetOwner( self.Owner )
	physExplo:SetPos( self.Entity:GetPos() )
	physExplo:SetKeyValue( "Magnitude", "1000" )	-- Power of the Physicsexplosion
	physExplo:SetKeyValue( "radius", "1000" )	-- Radius of the explosion
	physExplo:SetKeyValue( "spawnflags", "1" )
	physExplo:Spawn()
	physExplo:Fire( "Explode", "", 0.02 )
	
	for k, v in pairs ( ents.FindInSphere( self.Entity:GetPos(), 250 ) ) do
		v:Fire( "EnableMotion", "", math.random( 0, 0.5 ) )
	end

	self:myGibs()
end


function ENT:PhysicsCollide( data, physobj )
	util.Decal("Scorch", data.HitPos + data.HitNormal , data.HitPos - data.HitNormal)
	if self.Dead == false then
		self.Dead = true
		self.Entity:EmitSound("offpv.explosion")
		self:Explosion()
		self.Entity:Remove()
	end
end

function ENT:OnRemove()
    if IsValid(self.myWeapon) and self.myWeapon.PDAOpen == true then
        self.myWeapon.PDAOpen = false
        self.myWeapon:Deploy()
    end
	self.Entity.myWeapon.GotRocket = false
	if self.Sound then self.Sound:Stop() self.Sound = nil end
end

