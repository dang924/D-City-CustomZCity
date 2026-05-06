if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "AFAK"
SWEP.Instructions = "LMB heals self, RMB heals target, R cycles selected body part."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 0.9
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/sweps/eft/afak/w_meds_afak.mdl"

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/hud/vgui_afak")
    SWEP.BounceWeaponIcon = true
    SWEP.IconOverride = "entities/weapon_afak.png"
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 2
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4.2684, -0.2728, 0.1779)
SWEP.offsetAng = Angle(160.0720, 20.0000, 90.0000)
SWEP.showstats = false

SWEP.IFAKSharedUsesMax = 120
SWEP.IFAKLimbHealCost = 20

SWEP.modes = 6
SWEP.modeNames = {
    [1] = "head",
    [2] = "chest",
    [3] = "left arm",
    [4] = "right arm",
    [5] = "left leg",
    [6] = "right leg",
}

SWEP.modeToOrgan = {
    [1] = {bone = "ValveBiped.Bip01_Head1", key = "skull", min = 0.6, healed = 0.59},
    [2] = {bone = "ValveBiped.Bip01_Spine2", key = "chest", min = 0.01, healed = 0},
    [3] = {bone = "ValveBiped.Bip01_L_UpperArm", key = "larm", min = 0.01, healed = 0, amputated = "larmamputated"},
    [4] = {bone = "ValveBiped.Bip01_R_UpperArm", key = "rarm", min = 0.01, healed = 0, amputated = "rarmamputated"},
    [5] = {bone = "ValveBiped.Bip01_L_Thigh", key = "lleg", min = 0.01, healed = 0, amputated = "llegamputated"},
    [6] = {bone = "ValveBiped.Bip01_R_Thigh", key = "rleg", min = 0.01, healed = 0, amputated = "rlegamputated"},
}

SWEP.ofsV = Vector(-2.0000, -10.0000, 8.0000)
SWEP.ofsA = Angle(90.0000, -90.0000, 90.0000)
SWEP.ShouldDeleteOnFullUse = false
SWEP.IFAKRegenAmount = 1
SWEP.IFAKRegenInterval = 7

local function clampInt(v, minV, maxV)
    return math.Clamp(math.floor(tonumber(v) or 0), minV, maxV)
end

function SWEP:GetSharedUsesMax()
    return clampInt(self.IFAKSharedUsesMax, 1, 999)
end

function SWEP:GetLimbHealCost()
    return clampInt(self.IFAKLimbHealCost, 1, 100)
end

function SWEP:GetSharedUses()
    if not istable(self.modeValues) then
        self.modeValues = { [1] = self:GetSharedUsesMax() }
    end

    local current = clampInt(self.modeValues[1], 0, self:GetSharedUsesMax())
    self.modeValues[1] = current
    return current
end

function SWEP:SetSharedUses(value)
    if not istable(self.modeValues) then
        self.modeValues = {}
    end

    self.modeValues[1] = clampInt(value, 0, self:GetSharedUsesMax())
end

function SWEP:InitializeAdd()
    self:SetHold(self.HoldType)
    self:SetSharedUses(self:GetSharedUsesMax())
    self.nextIFAKRegenAt = CurTime() + self.IFAKRegenInterval
end

function SWEP:TickPassiveRegen(curTime)
    if not SERVER then return end
    if IsValid(self:GetNWEntity("fakeGun")) then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local interval = math.max(tonumber(self.IFAKRegenInterval) or 7, 0.5)
    curTime = curTime or CurTime()
    self.nextIFAKRegenAt = self.nextIFAKRegenAt or (curTime + interval)
    if curTime < self.nextIFAKRegenAt then return end
    self.nextIFAKRegenAt = curTime + interval

    local current = self:GetSharedUses()
    local maxUses = self:GetSharedUsesMax()
    if current >= maxUses then return end

    local regen = clampInt(self.IFAKRegenAmount, 1, 20)
    self:SetSharedUses(math.min(current + regen, maxUses))
    self:SetNetVar("modeValues", self.modeValues)
end

function SWEP:Think()
    if self.BaseClass and self.BaseClass.Think then
        self.BaseClass.Think(self)
    end

    self:TickPassiveRegen(CurTime())
end

if SERVER then
    hook.Add("Think", "zc_afak_passive_regen_global", function()
        local curTime = CurTime()
        for _, ply in ipairs(player.GetAll()) do
            for _, wep in ipairs(ply:GetWeapons()) do
                if IsValid(wep) and wep:GetClass() == "weapon_afak_sh" and wep.TickPassiveRegen then
                    wep:TickPassiveRegen(curTime)
                end
            end
        end
    end)
end

SWEP.modeValuesdef = {
    [1] = {120, true},
}

function SWEP:SecondaryAttack()
    if SERVER then
        if IsValid(self:GetNWEntity("fakeGun")) then return end

        local ent = hg.eyeTrace(self:GetOwner()).Entity
        self.healbuddy = ent

        if not IsValid(self.healbuddy) then return end
        if hg.GetCurrentCharacter(self.healbuddy) == hg.GetCurrentCharacter(self:GetOwner()) then return end

        local done = self:Heal(self.healbuddy, self.mode)
        if done and self.PostHeal then
            self:PostHeal(self.healbuddy, self.mode)
        end

        if self.net_cooldown2 < CurTime() then
            self:SetNetVar("modeValues", self.modeValues)
        end
    end
end

function SWEP:Reload()
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if not owner:KeyPressed(IN_RELOAD) then return end

    self.mode = ((self.mode + 1) > self.modes) and 1 or (self.mode + 1)

    net.Start("select_mode")
    net.WriteEntity(self)
    net.WriteInt(self.mode, 4)
    net.Broadcast()
end

if CLIENT then
    local bgCol = Color(16, 20, 26, 190)
    local borderCol = Color(55, 68, 84, 220)
    local txtCol = Color(225, 235, 245, 250)
    local subCol = Color(150, 170, 190, 250)
    local barBg = Color(30, 36, 44, 220)

    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        if owner:InVehicle() then return end

        local maxUses = self.GetSharedUsesMax and self:GetSharedUsesMax() or 120
        local uses = self.GetSharedUses and self:GetSharedUses() or (self.modeValues and self.modeValues[1] or maxUses)
        local ratio = maxUses > 0 and math.Clamp(uses / maxUses, 0, 1) or 0

        local modeName = self.modeNames[self.mode] or "unknown"
        local panelW, panelH = 310, 74
        local x = ScrW() * 0.5 - panelW * 0.5
        local y = ScrH() - panelH - 86

        draw.RoundedBox(8, x, y, panelW, panelH, bgCol)
        surface.SetDrawColor(borderCol)
        surface.DrawOutlinedRect(x, y, panelW, panelH, 1)

        draw.SimpleText("AFAK", "DermaDefaultBold", x + 10, y + 8, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Target: " .. string.upper(modeName), "DermaDefault", x + 10, y + 26, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Uses: %d / %d", uses, maxUses), "DermaDefault", x + panelW - 10, y + 8, subCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        local barX, barY = x + 10, y + 48
        local barW, barH = panelW - 20, 14
        draw.RoundedBox(4, barX, barY, barW, barH, barBg)

        local fillCol = Color(110, 200, 120, 235)
        if ratio < 0.35 then
            fillCol = Color(220, 120, 95, 235)
        elseif ratio < 0.65 then
            fillCol = Color(210, 185, 95, 235)
        end
        draw.RoundedBox(4, barX + 1, barY + 1, (barW - 2) * ratio, barH - 2, fillCol)

        draw.SimpleText("LMB self  RMB target  R cycle limb", "DermaDefault", x + panelW * 0.5, y + panelH + 4, subCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

if SERVER then
    function SWEP:Heal(ent, mode)
        if ent:IsNPC() then
            self:NPCHeal(ent, 0.2, "snd_jack_hmcd_bandage.wav")
            return true
        end

        local org = ent.organism
        if not org then return end
        if self:GetSharedUses() <= 0 then return end

        local owner = self:GetOwner()
        local modeInfo = self.modeToOrgan[mode] or self.modeToOrgan[1]
        local remaining = math.min(self:GetSharedUses(), self:GetLimbHealCost())
        local spent = 0
        local didHeal = false

        if istable(org.wounds) and modeInfo.bone then
            for i = #org.wounds, 1, -1 do
                local wound = org.wounds[i]
                if wound and wound[4] == modeInfo.bone and remaining > 0 then
                    local woundBefore = wound[1] or 0
                    if woundBefore > 0 then
                        local woundTake = math.min(woundBefore, remaining)
                        wound[1] = math.max(woundBefore - woundTake, 0)
                        org.bleed = math.max((org.bleed or 0) - woundTake, 0)
                        remaining = remaining - woundTake
                        spent = spent + woundTake
                        didHeal = true
                        if wound[1] <= 0 then
                            table.remove(org.wounds, i)
                        end
                    end
                end
            end

            if IsValid(org.owner) then
                org.owner:SetNetVar("wounds", org.wounds)
            end
        end

        if modeInfo.key and not (modeInfo.amputated and org[modeInfo.amputated]) then
            local current = tonumber(org[modeInfo.key]) or 0
            if current >= (modeInfo.min or 0.01) then
                org[modeInfo.key] = modeInfo.healed
                spent = math.max(spent, math.min(self:GetLimbHealCost(), self:GetSharedUses()))
                didHeal = true
            end
        end

        if not didHeal then return end

        self:SetSharedUses(self:GetSharedUses() - spent)
        org.pain = math.max((org.pain or 0) - spent * 0.2, 0)
        org.avgpain = math.max((org.avgpain or 0) - spent * 0.2, 0)

        self:SetNetVar("modeValues", self.modeValues)

        owner:EmitSound("snd_jack_hmcd_bandage.wav", 60, math.random(95, 105))

        if self.poisoned2 then
            org.poison4 = CurTime()
            self.poisoned2 = nil
        end

        if self:GetSharedUses() <= 0 and self.ShouldDeleteOnFullUse then
            owner:SelectWeapon("weapon_hands_sh")
            self:Remove()
        end

        return true
    end
end
