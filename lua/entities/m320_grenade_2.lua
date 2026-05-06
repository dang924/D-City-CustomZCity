ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "M320 Grenade"
ENT.Category		= "None"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false


ENT.MyModel = "models/items/ar2_grenade.mdl"
ENT.MyModelScale = 1
ENT.Damage = (engine.ActiveGamemode() == "sandbox" and 120) or 240
ENT.Radius = (engine.ActiveGamemode() == "sandbox" and 110) or 220
if SERVER then

	AddCSLuaFile()

	function ENT:Initialize()

		local model = self.MyModel and self.MyModel or "models/weapons/w_sgv_hx25_nade.mdl"

		self.Class = self:GetClass()

		self:SetModel(model)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		if engine.ActiveGamemode() == "zombiesurvival" then
			self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			else
			self:SetCollisionGroup(COLLISION_GROUP_NONE)
		end
		self:SetHealth(1)
		self:SetModelScale(self.MyModelScale,0)
		util.SpriteTrail(self, 0, Color(255,255,255), false, 4, 1, 0.4, 0.125, "trails/smoke.vmt")

		local phys = self:GetPhysicsObject()

		if (phys:IsValid()) then
			phys:Wake()
		end
	end

	function ENT:PhysicsCollide(data, physobj)
		local owent = self.Owner and self.Owner or self
		util.BlastDamage(self,owent,self:GetPos(),self.Radius,self.Damage)
		local fx = EffectData()
		fx:SetOrigin(self:GetPos())
		fx:SetNormal(data.HitNormal)
		util.Effect("Explosion",fx)
		self:EmitSound("L4D2_PORTS.M320.Explode",110,100,1,CHAN_WEAPON)
		self:Remove()
	end
end

if CLIENT then

	function ENT:Draw()
		self:DrawModel()
	end

end