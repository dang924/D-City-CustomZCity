if SERVER then AddCSLuaFile() end

SWEP.PrintName = "Refill Crate Deployer"
SWEP.Instructions = "LMB place selected crate. R toggles crate type."
SWEP.Category = "ZCity Utilities"
SWEP.Spawnable = true

SWEP.ViewModel = ""
SWEP.WorldModel = "models/Items/item_item_crate_dynamic.mdl"
SWEP.HoldType = "shotgun"

if CLIENT then
    SWEP.WepSelectIcon = Material("vgui/inventory/perk_quick_reload")
    SWEP.IconOverride = "spawnicons/models/items/item_item_crate_dynamic.png"
    SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 4
SWEP.SlotPos = 9

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(-12.6407, 19.7158, 4.3550)
SWEP.offsetAng = Angle(178.661, 112.939, 92.274)
SWEP.ofsV = Vector(-4, -8, 9)
SWEP.ofsA = Angle(96.317, -90, 90)

if CLIENT then
    function SWEP:DrawWorldModel()
        self.model = IsValid(self.model) and self.model or ClientsideModel(self.WorldModel)
        if not IsValid(self.model) then return end

        self.model:SetNoDraw(true)

        local owner = self:GetOwner()
        if IsValid(owner) then
            local boneid = owner:LookupBone("ValveBiped.Bip01_Spine")
            if not boneid then return end

            local matrix = owner:GetBoneMatrix(boneid)
            if not matrix then return end

            local offsetVec = self.offsetVec or vector_origin
            local offsetAng = self.offsetAng or angle_zero
            local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())

            self.model:SetPos(newPos)
            self.model:SetAngles(newAng)
            self.model:SetupBones()
        else
            self.model:SetPos(self:GetPos())
            self.model:SetAngles(self:GetAngles())
        end

        self.model:DrawModel()
    end
end

SWEP.CrateDefs = {
    [1] = {
        name = "Small Wooden Crate",
        model = "models/Items/item_item_crate.mdl",
        uses = 20,
        cooldown = 30,
        kind = "small",
        cooldownKey = "RefillCrateCooldownSmall",
    },
    [2] = {
        name = "AR2 Ammo Crate",
        model = "models/Items/ammocrate_ar2.mdl",
        uses = 100,
        cooldown = 300,
        kind = "ar2",
        cooldownKey = "RefillCrateCooldownAR2",
    },
}

local function getCooldownEnd(owner, key)
    return owner:GetNWFloat(key, 0)
end

local function setCooldownEnd(owner, key, value)
    owner:SetNWFloat(key, value)
end

function SWEP:TickPocketCooldown(curTime)
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    curTime = curTime or CurTime()

    local smallEnd = owner:GetNWFloat("RefillCrateCooldownSmall", 0)
    local ar2End = owner:GetNWFloat("RefillCrateCooldownAR2", 0)

    if smallEnd > 0 and smallEnd <= curTime then
        smallEnd = 0
        owner:SetNWFloat("RefillCrateCooldownSmall", 0)
    end

    if ar2End > 0 and ar2End <= curTime then
        ar2End = 0
        owner:SetNWFloat("RefillCrateCooldownAR2", 0)
    end

    owner:SetNWFloat("RefillCrateCooldownSmallRemain", math.max(smallEnd - curTime, 0))
    owner:SetNWFloat("RefillCrateCooldownAR2Remain", math.max(ar2End - curTime, 0))
end

function SWEP:Initialize()
    self:SetWeaponHoldType(self.HoldType)
    self.deployMode = self.deployMode or 1

    if SERVER then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:SetNWInt("RefillCrateDeployMode", self.deployMode)
        end
    end
end

function SWEP:Deploy()
    self:SetWeaponHoldType(self.HoldType)
    if SERVER then
        local owner = self:GetOwner()
        if IsValid(owner) then
            self.deployMode = self.deployMode or 1
            owner:SetNWInt("RefillCrateDeployMode", self.deployMode)
        end
    end
    return true
end

function SWEP:Reload()
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if not owner:KeyPressed(IN_RELOAD) then return end

    self.deployMode = self.deployMode == 2 and 1 or 2
    owner:SetNWInt("RefillCrateDeployMode", self.deployMode)

    local def = self.CrateDefs[self.deployMode]
    owner:ChatPrint("Deploy mode: " .. def.name)
end

function SWEP:CanPlace(def)
    local owner = self:GetOwner()
    if not IsValid(owner) then return false, "No owner" end

    local coolEnd = getCooldownEnd(owner, def.cooldownKey)
    local remaining = coolEnd - CurTime()
    if remaining > 0 then
        return false, string.format("%s cooldown: %.1fs", def.name, remaining)
    end

    return true
end

function SWEP:PrimaryAttack()
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local def = self.CrateDefs[self.deployMode or 1]
    if not def then return end

    local ok, reason = self:CanPlace(def)
    if not ok then
        owner:ChatPrint(reason)
        self:SetNextPrimaryFire(CurTime() + 0.35)
        return
    end

    local tr = util.TraceHull({
        start = owner:EyePos(),
        endpos = owner:EyePos() + owner:GetAimVector() * 85,
        filter = owner,
        mins = Vector(-6, -6, -6),
        maxs = Vector(6, 6, 6),
        mask = MASK_SOLID_BRUSHONLY,
    })

    if not tr.Hit then
        owner:ChatPrint("Aim at a nearby surface")
        self:SetNextPrimaryFire(CurTime() + 0.35)
        return
    end

    local spawnPos = tr.HitPos + tr.HitNormal * 2
    local spawnAng = Angle(0, owner:EyeAngles().y, 0)

    local ent = ents.Create("ent_zc_refill_crate")
    if not IsValid(ent) then return end

    ent.Model = def.model
    ent:SetPos(spawnPos)
    ent:SetAngles(spawnAng)
    ent.UsesMax = def.uses
    ent.UsesLeft = def.uses
    ent.CrateKind = def.kind
    ent:Spawn()

    setCooldownEnd(owner, def.cooldownKey, CurTime() + def.cooldown)
    owner:EmitSound("snd_jack_hmcd_ammobox.wav", 70, 105, 0.7, CHAN_ITEM)

    self:SetNextPrimaryFire(CurTime() + 0.6)
end

function SWEP:Think()
    self:TickPocketCooldown(CurTime())
end

function SWEP:SecondaryAttack()
end

if CLIENT then
    local bgCol = Color(16, 20, 26, 185)
    local borderCol = Color(55, 68, 84, 220)
    local txtCol = Color(225, 235, 245, 250)
    local subCol = Color(165, 180, 200, 250)
    local barBg = Color(30, 36, 44, 220)

    local function drawCooldownBar(x, y, w, h, title, remaining, total, selected)
        local ratio = total > 0 and math.Clamp(remaining / total, 0, 1) or 0
        local fillCol = ratio > 0 and Color(220, 125, 90, 235) or Color(105, 200, 120, 235)
        local titleCol = selected and Color(255, 235, 165, 250) or txtCol

        draw.SimpleText(title, "DermaDefault", x, y - 14, titleCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(remaining > 0 and string.format("%.1fs", remaining) or "Ready", "DermaDefault", x + w, y - 14, subCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        draw.RoundedBox(4, x, y, w, h, barBg)
        draw.RoundedBox(4, x + 1, y + 1, (w - 2) * (1 - ratio), h - 2, fillCol)
    end

    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        if owner:InVehicle() then return end

        local panelW, panelH = 360, 112
        local x = ScrW() * 0.5 - panelW * 0.5
        local y = ScrH() - panelH - 84

        draw.RoundedBox(8, x, y, panelW, panelH, bgCol)
        surface.SetDrawColor(borderCol)
        surface.DrawOutlinedRect(x, y, panelW, panelH, 1)

        draw.SimpleText("Refill Crate Deployer", "DermaDefaultBold", x + 10, y + 8, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local mode = owner:GetNWInt("RefillCrateDeployMode", 1)
        local now = CurTime()
        local smallRemain = owner:GetNWFloat("RefillCrateCooldownSmallRemain", math.max(owner:GetNWFloat("RefillCrateCooldownSmall", 0) - now, 0))
        local ar2Remain = owner:GetNWFloat("RefillCrateCooldownAR2Remain", math.max(owner:GetNWFloat("RefillCrateCooldownAR2", 0) - now, 0))

        drawCooldownBar(x + 10, y + 38, panelW - 20, 16, "Small crate (20 uses)", smallRemain, 30, mode == 1)
        drawCooldownBar(x + 10, y + 72, panelW - 20, 16, "AR2 crate (100 uses)", ar2Remain, 300, mode == 2)

        draw.SimpleText("LMB place selected crate  |  R toggle type", "DermaDefault", x + panelW * 0.5, y + panelH - 8, subCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end

if SERVER then
    hook.Add("Think", "zc_refill_crate_deployer_pocket_tick", function()
        local curTime = CurTime()
        for _, ply in ipairs(player.GetAll()) do
            for _, wep in ipairs(ply:GetWeapons()) do
                if IsValid(wep) and wep:GetClass() == "weapon_refill_crate_deployer" and wep.TickPocketCooldown then
                    wep:TickPocketCooldown(curTime)
                end
            end
        end
    end)
end
