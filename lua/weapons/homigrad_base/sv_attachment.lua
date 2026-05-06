local attachsounds = {
	"arc9_eft_shared/weap_bolt_catch.ogg",
	"arc9_eft_shared/weap_ar_pickup.ogg",
	"arc9_eft_shared/weap_bolt_out.ogg",
	"arc9_eft_shared/weap_dmr_pickup.ogg",
	"arc9_eft_shared/weap_dmr_use.ogg",
	"arc9_eft_shared/weap_pump_drop.ogg",
	"arc9_eft_shared/weap_rifle_pickup.ogg",
	"arc9_eft_shared/weap_rifle_drop.ogg",
	"arc9_eft_shared/weap_rifle_use.ogg"
}

util.AddNetworkString("ZB_AttachAdd")
util.AddNetworkString("ZB_AttachRemove")
util.AddNetworkString("ZB_AttachDrop")
net.Receive("ZB_AttachAdd", function(len, ply)
	local att = net.ReadString()
	local wep = ply:GetActiveWeapon()
	hg.AddAttachment(ply,wep,att)
	//ply:SetNetVar("Inventory",ply.inventory)
end)

local function ShouldUseZScavAttachmentBridge(ply)
	return IsValid(ply) and ZSCAV and ZSCAV.IsActive and ZSCAV:IsActive()
end

local function EnsureLegacyAttachmentInventory(ply)
	if not IsValid(ply) then return {} end

	local netInventory = ply:GetNetVar("Inventory", {})
	local legacyInventory = istable(ply.inventory) and ply.inventory or (istable(netInventory) and table.Copy(netInventory) or {})
	legacyInventory.Attachments = istable(legacyInventory.Attachments) and legacyInventory.Attachments or {}
	ply.inventory = legacyInventory
	return legacyInventory
end

local function NormalizeAttachmentResource(att)
	if ZSCAV and ZSCAV.NormalizeAttachmentKey then
		return ZSCAV:NormalizeAttachmentKey(att)
	end

	return string.Trim(string.lower(tostring(att or "")))
end

local function PlayerHasAttachmentResource(ply, att)
	att = NormalizeAttachmentResource(att)
	if att == "" or not IsValid(ply) then return false end

	if ShouldUseZScavAttachmentBridge(ply) and ZSCAV.HasAttachmentResource then
		return ZSCAV:HasAttachmentResource(ply, att)
	end

	local legacyInventory = EnsureLegacyAttachmentInventory(ply)
	return table.HasValue(legacyInventory.Attachments, att)
end

local function ConsumeAttachmentResource(ply, att)
	att = NormalizeAttachmentResource(att)
	if att == "" or not IsValid(ply) then return false, "invalid" end

	if ShouldUseZScavAttachmentBridge(ply) and ZSCAV.ConsumeAttachmentResource then
		return ZSCAV:ConsumeAttachmentResource(ply, att)
	end

	local legacyInventory = EnsureLegacyAttachmentInventory(ply)
	if not table.HasValue(legacyInventory.Attachments, att) then
		return false, "missing"
	end

	table.RemoveByValue(legacyInventory.Attachments, att)
	ply:SetNetVar("Inventory", legacyInventory)
	return true, "legacy"
end

local function StoreDetachedAttachment(ply, att)
	att = NormalizeAttachmentResource(att)
	if att == "" or not IsValid(ply) then return false, "invalid" end

	if ShouldUseZScavAttachmentBridge(ply) and ZSCAV.StashDetachedAttachment then
		return ZSCAV:StashDetachedAttachment(ply, att)
	end

	local legacyInventory = EnsureLegacyAttachmentInventory(ply)
	legacyInventory.Attachments[#legacyInventory.Attachments + 1] = att
	ply:SetNetVar("Inventory", legacyInventory)
	return true, "legacy"
end

local function RefreshZScavWeaponState(ply, wep)
	if ShouldUseZScavAttachmentBridge(ply) and ZSCAV.SyncHeldWeaponEntryState then
		ZSCAV:SyncHeldWeaponEntryState(ply, wep)
	end
end

function hg.AddAttachment(ply,wep,att)
	if wep:GetNWFloat("addAttachment", 0) + 1 > CurTime() then return end

	if not IsValid(wep) or not wep.attachments then return end
	if not IsValid(ply) then return end

	if att and istable(att) then
		for i,atta in pairs(att) do
			hg.AddAttachment(ply,wep,atta)
		end
		return
	end

	att = NormalizeAttachmentResource(att)
	if att == "" then return end
	if not PlayerHasAttachmentResource(ply, att) then return end

	local organism = ply.organism or {}
	if organism.larmamputated or organism.rarmamputated then return end -- зубами

	local placement = nil
	local placementAttachments = nil

	for plc, tbl in pairs(hg.attachments or {}) do
		if istable(tbl) and tbl[att] then
			placement = plc
			placementAttachments = tbl
			break
		end
	end

	local attDef = placementAttachments and placementAttachments[att] or nil
	local slotState = placement and wep.attachments[placement] or nil
	local availableAttachments = placement and wep.availableAttachments and wep.availableAttachments[placement] or nil
	if not placement or not istable(attDef) or not istable(slotState) or not istable(availableAttachments) then return end

	if not slotState.noblock then
		local restrictAtt = attDef.restrictatt
		
		for i, installedAtt in pairs(wep.attachments) do
			if not installedAtt or not istable(installedAtt) or table.IsEmpty(installedAtt) or installedAtt[1] == "empty" then continue end

			local installedPlacement = hg.attachments[i]
			local installedDef = istable(installedPlacement) and installedPlacement[installedAtt[1]] or nil
			local installedAvailable = wep.availableAttachments and wep.availableAttachments[i] or nil
			if restrictAtt then
				if istable(installedDef) and installedDef[1] == restrictAtt then
					ply:ChatPrint("There is no space for this attachment.")
					return
				end
			else
				if not (installedAvailable and installedAvailable.noblock) and istable(installedDef) and installedDef.restrictatt == placement then
					ply:ChatPrint("There is no space for this attachment.")
					return
				end
			end
		end
	end

	if not (table.IsEmpty(slotState) or slotState[1] == "empty") then
		ply:ChatPrint("There is no space for this attachment.")
		return
	end
	
	--if not wep.availableAttachments[placement] then return end
	local i
	for n, atta in pairs(availableAttachments) do
			i = istable(atta) and atta[1] == att and n or i
	end
	
	--if not i then ply:ChatPrint("You cant place this attachment on this weapon.") return end
	local mountType = availableAttachments["mountType"]
	local mountType2 = attDef.mountType
	
	if not availableAttachments[i] and not (mountType or mountType2) then return end
	local mounts = istable(mountType) and table.HasValue(mountType, mountType2) or mountType == mountType2
	
	if not mounts then
		return
	end
	

	wep:AttachAnim()
	timer.Simple(0.5,function()
		if wep:IsValid() then
			local consumed = ConsumeAttachmentResource(ply, att)
			if not consumed then return end

				wep.attachments[placement] = i and availableAttachments[i] or {att, {}}

			wep:SyncAtts()
			wep:EmitSound(attachsounds[math.random(#attachsounds)], 40)
			RefreshZScavWeaponState(ply, wep)
		end
	end)
end

function hg.AddAttachmentForce(ply,wep,att)
	if not IsValid(wep) or not wep.attachments or att == "" then return end
	
	if att and istable(att) then
		for i,atta in pairs(att) do
			hg.AddAttachmentForce(ply,wep,atta)
		end
		return
	end

	local placement = nil

	for plc, tbl in pairs(hg.attachments) do
		placement = tbl[att] and tbl[att][1] or placement
	end

	if not wep.attachments[placement].noblock then
		local restrictAtt = hg.attachments[placement][att].restrictatt
		
		for i,att in pairs(wep.attachments) do
			if not att or not istable(att) or table.IsEmpty(att) or att[1] == "empty" then continue end
		end
	end

	if not placement then return end

	--if not wep.availableAttachments[placement] then return end
	local i
	if wep.availableAttachments[placement] then
		for n, atta in pairs(wep.availableAttachments[placement]) do
			i = istable(atta) and atta[1] == att and n or i
		end
	end
	
	--if not i then ply:ChatPrint("You cant place this attachment on this weapon.") return end
	local mountType = wep.availableAttachments[placement] and wep.availableAttachments[placement]["mountType"]
	local mountType2 = hg.attachments[placement][att] and hg.attachments[placement][att].mountType
	if not wep.availableAttachments[placement] then return end
	
	if not wep.availableAttachments[placement][i] and not (mountType or mountType2) then return end
	local mounts = istable(mountType) and table.HasValue(mountType, hg.attachments[placement][att].mountType) or mountType == mountType2
	
	if not mounts then
		return
	end

	wep.attachments[placement] = i and wep.availableAttachments[placement][i] or {att, {}}
	timer.Simple(.1,function()
		if wep:IsValid() then
			wep:SyncAtts()
			RefreshZScavWeaponState(ply, wep)
		end
	end)
end

net.Receive("ZB_AttachRemove", function(len, ply)
	local att = net.ReadString()
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or not wep.attachments then return end
	if wep:GetNWFloat("addAttachment", 0) + 1 > CurTime() then return end
	if not IsValid(ply) then return end
	if ply.organism.larmamputated or ply.organism.rarmamputated then return end
	--[[if table.HasValue(ply.inventory.Attachments, att) then
		ply:ChatPrint("You already have that attachment.")
		return
	end--]]

	local placement = nil
	for plc, tbl in pairs(hg.attachments) do
		placement = tbl[att] and tbl[att][1] or placement
	end

	if not placement then return end
	if wep.attachments[placement][1] != att then return end
	if table.IsEmpty(wep.attachments[placement]) or wep.attachments[placement][1] == "empty" then return end
	if wep.availableAttachments[placement].cannotremove then return end
	local i
	for n, atta in pairs(wep.availableAttachments[placement]) do
		i = istable(atta) and atta[1] == "empty" and n or i
	end
	
	wep:AttachAnim()
	timer.Simple(0.5, function()
		if IsValid(wep) then
			if wep.attachments[placement][1] != att then return end
			local stored, reason = StoreDetachedAttachment(ply, att)
			if not stored then
				if reason == "space" or reason == "weight" then
					ply:ChatPrint("No room for this attachment.")
				else
					ply:ChatPrint("Could not stash this attachment.")
				end
				return
			end
			wep.attachments[placement] = i and wep.availableAttachments[placement][i] or {}
			wep:SyncAtts()
			wep:EmitSound(attachsounds[math.random(#attachsounds)], 40)
			RefreshZScavWeaponState(ply, wep)
		end
	end)
end)

net.Receive("ZB_AttachDrop", function(len, ply)
	local att = net.ReadString()
	local placement = nil
	for plc, tbl in pairs(hg.attachments) do
		placement = tbl[att] and tbl[att][1] or placement
	end

	if not placement then return end

	if not PlayerHasAttachmentResource(ply, att) then return end

	if hg.attachments[placement][att] then
		local attEnt = ents.Create("ent_att_" .. att)
		if not IsValid(attEnt) then return end
		attEnt:Spawn()
		attEnt:SetPos(ply:EyePos())
		attEnt:SetAngles(ply:EyeAngles())
		local phys = attEnt:GetPhysicsObject()
		if IsValid(phys) then phys:SetVelocity(ply:EyeAngles():Forward() * 100) end
		local consumed = ConsumeAttachmentResource(ply, att)
		if not consumed and IsValid(attEnt) then
			attEnt:Remove()
		end
	end
end)

util.AddNetworkString("sync_atts")
util.AddNetworkString("sync_atts_ply")
local PLAYER = FindMetaTable("Player")
function SWEP:SyncAtts(ply)
	self:SetNetVar("attachments",self.attachments)
	self:SendNetVar("attachments")
end

net.Receive("sync_atts", function(len, ply)
	--local self = net.ReadEntity()
	--if self:GetOwner() != ply then return end

	--self:SyncAtts(ply)
end)