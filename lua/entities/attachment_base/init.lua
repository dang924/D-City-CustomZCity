AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
function ENT:Initialize()
	self:SetModel(self.PhysModel or self.Model)
	for i, submat in ipairs(self.SubMats) do
		self:SetSubMaterial(i, isstring(submat) and submat or "null")
	end

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetUseType(SIMPLE_USE)
	self:DrawShadow(false)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(10)
		phys:Wake()
		phys:EnableMotion(true)
	end
end

function ENT:OnRemove()
end

function ENT:Use(activator)
	self:TakeByPlayer(activator)
end

function ENT:TakeByPlayer(activator)
	if activator:IsPlayer() then-- and not table.HasValue(activator.inventory.Attachments, self.name) then
		if ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive() and ZSCAV.GrantAttachmentResource then
			local helpers = ZSCAV.ServerHelpers or {}
			local handleUnconfiguredPickup = helpers.HandleUnconfiguredPickup
			if isfunction(handleUnconfiguredPickup) and handleUnconfiguredPickup(activator, self:GetClass(), false) then
				return
			end

			local ok, reason = ZSCAV:GrantAttachmentResource(activator, self.name, {
				allowDuplicate = true,
			})
			if not ok then
				if reason == "space" or reason == "weight" then
					activator:ChatPrint("No room for this attachment.")
				end
				return
			end
			self:EmitSound("physics/metal/weapon_impact_soft" .. math.random(3) .. ".wav", 65, math.random(90, 110), 1, CHAN_ITEM)
			self:Remove()
			return
		end

		activator.inventory = activator:GetNetVar("Inventory") or activator.inventory
		activator.inventory.Attachments[#activator.inventory.Attachments + 1] = self.name
		activator:SetNetVar("Inventory",activator.inventory)
		self:EmitSound("physics/metal/weapon_impact_soft" .. math.random(3) .. ".wav", 65, math.random(90, 110), 1, CHAN_ITEM)
		self:Remove()
	end
end