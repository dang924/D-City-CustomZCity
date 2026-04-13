if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Splint"
SWEP.Instructions = "A rigid splint for stabilizing fractures. Repairs one random broken arm/leg bone per use."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true

SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/tourniquet/tourniquet.mdl"

if CLIENT then
    SWEP.WepSelectIcon = Material("scrappers/jgut.png")
    SWEP.IconOverride = "scrappers/jgut.png"
    SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -1.5, 0)
SWEP.offsetAng = Angle(-30, 20, -90)
SWEP.ModelScale = 1

SWEP.modeNames = {
    [1] = "splint",
}

function SWEP:InitializeAdd()
    self:SetHold(self.HoldType)

    self.modeValues = {
        [1] = 1,
    }
end

SWEP.showstats = false
SWEP.modeValuesdef = {
    [1] = 1,
}

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

function SWEP:Think()
    if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
        self:SetHolding(math.max(self:GetHolding() - 12, 0))
    end
end

local function CanRepair(value)
    return isnumber(value) and value >= 1
end

local LIMB_BONES = {
    { key = "lleg", amputated = "llegamputated", name = "left leg" },
    { key = "rleg", amputated = "rlegamputated", name = "right leg" },
    { key = "larm", amputated = "larmamputated", name = "left arm" },
    { key = "rarm", amputated = "rarmamputated", name = "right arm" },
}

local SPLINT_VISUAL_BONES = {
    lleg = "ValveBiped.Bip01_L_Calf",
    rleg = "ValveBiped.Bip01_R_Calf",
    larm = "ValveBiped.Bip01_L_Forearm",
    rarm = "ValveBiped.Bip01_R_Forearm",
}

local function GetRepairCandidates(org)
    local candidates = {}

    for _, bone in ipairs(LIMB_BONES) do
        if bone.amputated and org[bone.amputated] then continue end
        if not CanRepair(org[bone.key]) then continue end
        candidates[#candidates + 1] = bone
    end

    return candidates
end

if SERVER then
    SWEP.ShouldDeleteOnFullUse = true

    local function AddSplintVisual(ply, limbKey)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local boneName = SPLINT_VISUAL_BONES[limbKey]
        if not boneName then return end

        ply.splints = ply.splints or {}

        for _, info in ipairs(ply.splints) do
            if istable(info) and info[1] == boneName then
                return
            end
        end

        ply.splints[#ply.splints + 1] = { boneName }
        ply:SetNetVar("Splints", ply.splints)

        if IsValid(ply.FakeRagdoll) then
            ply.FakeRagdoll.splints = table.Copy(ply.splints)
            ply.FakeRagdoll:SetNetVar("Splints", ply.FakeRagdoll.splints)
        end
    end

    function SWEP:Heal(ent)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local target = hg.GetCurrentCharacter(ent)
        local org = target and target.organism
        if not org then return end

        if target == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
            self:SetHolding(math.min(self:GetHolding() + 10, 100))
            if self:GetHolding() < 100 then return end
        end

        local candidates = GetRepairCandidates(org)
        if #candidates <= 0 then return false end

        local pick = candidates[math.random(#candidates)]
        org[pick.key] = 0.59
        org.avgpain = math.max((org.avgpain or 0) - 10, 0)

        local visualTarget = (IsValid(target) and target:IsPlayer() and target) or org.owner
        if IsValid(visualTarget) and visualTarget:IsPlayer() then
            AddSplintVisual(visualTarget, pick.key)
        end

        owner:EmitSound("snd_jack_hmcd_bandage.wav", 60, math.random(95, 105))

        if IsValid(target) and target:IsPlayer() then
            target:ChatPrint("[Splint] Fracture stabilized: " .. pick.name .. ".")
        end

        self.modeValues[1] = 0
        if self.ShouldDeleteOnFullUse then
            owner:SelectWeapon("weapon_hands_sh")
            self:Remove()
        end

        return true
    end
end
