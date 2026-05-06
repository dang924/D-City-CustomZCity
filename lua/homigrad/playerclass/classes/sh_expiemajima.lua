local CLASS = player.RegClass("expiemajima")
local random_lines = {}
for i = 1, 53 do random_lines[i] = "playerclasses/goromajima/" .. i .. ".wav" end
local pain_lines = {}
for i = 1, 4 do pain_lines[i] = "playerclasses/goromajima/pain" .. i .. ".wav" end
local melee_lines = {}
for i = 1, 4 do melee_lines[i] = "playerclasses/goromajima/melee" .. i .. ".wav" end
local onhit_lines = {}
for i = 1, 4 do onhit_lines[i] = "playerclasses/goromajima/onhit" .. i .. ".wav" end
local steps = {}
for i = 1, 4 do steps[i] = "playerclasses/expie/steps" .. i .. ".wav" end

function CLASS.Off(self)
    if CLIENT then return end
    if self.oldRunSpeed then
        self:SetRunSpeed(self.oldRunSpeed)
        self.oldRunSpeed = nil
    end
    self.StaminaExhaustMul = nil
    self.SpeedGainClassMul = nil
    self.Expiemajima_BeingVictimOfNeckBreak = false
    if self.Expiemajima_NeckBreakAbility then
        self.Expiemajima_NeckBreakAbility = nil
    end
end

function CLASS.Guilt(self, Victim)
    if CLIENT then return end
end

hook.Add("HG_PlayerFootstep", "expiemajima_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "expiemajima" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if ent == ply then
        if #steps == 0 then return end
        local random_sound = steps[math.random(#steps)]
        local final_volume = math.Clamp(volume * 1.5, 0.5, 1.0)
        EmitSound(random_sound, pos, ply:EntIndex(), CHAN_BODY, final_volume, 100, 0, math.random(95, 105))
        return true
    end
end)

function CLASS.On(self, data)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AClothes = ""
    self:SetNetVar("Accessories", "")
    self:SetSubMaterial()
    self.CurAppearance = Appearance
    self:SetNWString("PlayerName","Expie the Mad Dog")
    self:SetPlayerColor(Vector(255,255,255))
    self:SetModel("models/conventionalgoofball/expie/expie.mdl")
    self.VoicePitch = 100
    self:SetBodygroup(10,1)
    self:SetBodygroup(2,0)
    self:SetBodygroup(3,0)
    self:SetBodygroup(4,0)
    self:SetBodygroup(5,0)
    self:SetBodygroup(6,0)
    self:SetBodygroup(7,0)
    self.oldRunSpeed = self.oldRunSpeed or self:GetRunSpeed()
    self:SetRunSpeed(self.oldRunSpeed * 1.19)
    self.StaminaExhaustMul = 1.25
    self.SpeedGainClassMul = 1.2
    self.VoicePitch = 120
end

hook.Add("HG_ReplacePhrase", "ExpieMajimaPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "expiemajima" then return end
    local org = ply.organism
    local inpainscream = org and org.pain > 60 and org.pain < 100
    local inpain = org and org.pain > 100
    local new_phrase
    if inpainscream or inpain then
        new_phrase = table.Random(pain_lines)
    else
        new_phrase = table.Random(random_lines)
    end
    ply._nextSound = inpain and (inpainscream and pain_line) or table.Random(random_lines)
    return ent, new_phrase, muffed, pitch
end)

if SERVER then
    local onhit_index = 1
    local melee_index = 1

    local function CanVocalise(ply)
        if not IsValid(ply) or not ply:Alive() then return false end
        local org = ply.organism
        if not org then return false end
        if org.otrub then return false end
        if ply:WaterLevel() >= 3 then return false end
        if hg.GetCurrentCharacter(ply):IsOnFire() then return false end
        if org.pain > 60 then return false end
        if org.holdingbreath then return false end
        if org.o2 and org.o2[1] and org.o2[1] < 15 then return false end
        return true
    end

    local function PlaySequentialSound(ply, soundTable, indexVar)
        if #soundTable == 0 then return end
        local idx = _G[indexVar] or 1
        local snd = soundTable[idx]
        _G[indexVar] = (idx % #soundTable) + 1
        local muffed = ply.armors and ply.armors["face"] == "mask2"
        local volume = muffed and 65 or 75
        local pitch = ply.VoicePitch or 100
        local dsp = muffed and 16 or 0
        ply:EmitSound(snd, volume, pitch, 1, CHAN_AUTO, 0, dsp)
    end

    hook.Add("HomigradDamage", "expiemajima_onhit", function(victim, dmgInfo, hitgroup, ent, harm, hitBoxs, inputHole)
        if not IsValid(victim) or victim.PlayerClassName ~= "expiemajima" then return end
        if not CanVocalise(victim) then return end
        if (victim.expiemajima_onhit_cd or 0) > CurTime() then return end
        victim.expiemajima_onhit_cd = CurTime() + 0.5
        PlaySequentialSound(victim, onhit_lines, "expiemajima_onhit_index")
    end)

    hook.Add("HomigradDamage", "expiemajima_melee", function(victim, dmgInfo, hitgroup, ent, harm, hitBoxs, inputHole)
        local attacker = dmgInfo:GetAttacker()
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        if attacker.PlayerClassName ~= "expiemajima" then return end
        if not CanVocalise(attacker) then return end
        if not dmgInfo:IsDamageType(DMG_CLUB + DMG_SLASH) then return end
        if (attacker.expiemajima_melee_cd or 0) > CurTime() then return end
        attacker.expiemajima_melee_cd = CurTime() + 0.1
        PlaySequentialSound(attacker, melee_lines, "expiemajima_melee_index")
    end)
end
local function NeckSnap_Trace(ply, dist)
    dist = dist or 85
    if hg and hg.eyeTrace then
        return hg.eyeTrace(ply, dist)
    end
    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * dist,
        filter = ply
    })
    return tr
end
local function NeckSnap_GetTarget(aim_ent)
    if not IsValid(aim_ent) then return nil end
    if aim_ent:IsPlayer() then return aim_ent end
    if aim_ent:IsRagdoll() then
        if hg and hg.RagdollOwner then
            return hg.RagdollOwner(aim_ent)
        else
            if aim_ent.ply then return aim_ent.ply end
        end
    end
    return nil
end
local function NeckSnap_CanBreak(ply, aim_ent)
    if not IsValid(ply) or not IsValid(aim_ent) then return false end
    local other_ply = NeckSnap_GetTarget(aim_ent)
    if not IsValid(other_ply) or not other_ply:Alive() then return false end
    if aim_ent:IsRagdoll() then
        local bone_id = aim_ent:LookupBone("ValveBiped.Bip01_Head1")
        if bone_id then
            local bone_matrix = aim_ent:GetBoneMatrix(bone_id)
            if bone_matrix then
                local pos, ang = bone_matrix:GetTranslation(), bone_matrix:GetAngles()
                local other_normal = -ang:Right()
                local ply_normal = pos - ply:GetShootPos()
                local dist_z = math.abs(pos.z - ply:GetShootPos().z)
                if dist_z < 50 then
                    ply_normal:Normalize()
                    local ang_diff = -(math.deg(math.acos(ply_normal:DotProduct(other_normal))) - 180)
                    return ang_diff < 100
                end
            end
        end
    elseif aim_ent:IsPlayer() then
        local other_angle = aim_ent:EyeAngles()[2]
        local ply_angle = (aim_ent:GetPos() - ply:GetPos()):Angle()[2]
        local ang_diff = math.abs(math.AngleDifference(other_angle, ply_angle))
        return ang_diff < 100
    end
    return false
end
if SERVER then
    util.AddNetworkString("expiemajima_neckbreak_start")
    util.AddNetworkString("expiemajima_neckbreak_stop")
    util.AddNetworkString("expiemajima_neckbreak_complete")
end
if SERVER then
    hook.Add("HG_MovementCalc_2", "expiemajima_neckbreak_slow", function(mul, ply, cmd)
        if ply.Expiemajima_BeingVictimOfNeckBreak then
            mul[1] = mul[1] * 0.3
        end
    end)
    local function BreakNeck(attacker, victim, aim_ent)
        if not victim:Alive() then return end
        victim:Kill()
        victim:ViewPunch(Angle(0, 0, -10))
        if aim_ent.organism then aim_ent.organism.spine3 = 1 end
        aim_ent:EmitSound("neck_snap_01.wav", 60, 100, 1, CHAN_AUTO)
        timer.Simple(0.1, function()
            local ent = victim:GetNWEntity("RagdollDeath")
            if IsValid(ent) then
                ent:RemoveInternalConstraint(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Head1")))
                local spine = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Spine2"))
                local head = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Head1"))
                local pspine = ent:GetPhysicsObjectNum(spine)
                local phead = ent:GetPhysicsObjectNum(head)
                if pspine and phead then
                    local lpos, lang = WorldToLocal(phead:GetPos() + phead:GetAngles():Forward() * -2 + phead:GetAngles():Up() * -1.5, angle_zero, pspine:GetPos(), pspine:GetAngles())
                    phead:SetPos(pspine:GetPos() + pspine:GetAngles():Forward() * 12.9 + pspine:GetAngles():Right() * -1)
                    constraint.AdvBallsocket(ent, ent, spine, head, lpos, nil, 0, 0, -55, -90, -50, 55, 35, 50, 0, 0, 0, 0, 0)
                end
            end
        end)
    end
    net.Receive("expiemajima_neckbreak_complete", function(len, ply)
        if not IsValid(ply) or ply.PlayerClassName ~= "expiemajima" then return end
        local ability = ply.Expiemajima_NeckBreakAbility
        if not ability then return end
        local victim = ability.Victim
        local aim_ent = ability.AimEnt
        if IsValid(victim) and IsValid(aim_ent) and victim:Alive() and NeckSnap_CanBreak(ply, aim_ent) then
            BreakNeck(ply, victim, aim_ent)
        end
        ply.Expiemajima_NeckBreakAbility = nil
        if victim then victim.Expiemajima_BeingVictimOfNeckBreak = false end
        net.Start("expiemajima_neckbreak_stop")
        net.Send(ply)
    end)
    net.Receive("expiemajima_neckbreak_start", function(len, ply)
        if not IsValid(ply) or ply.PlayerClassName ~= "expiemajima" then return end
        if ply.Expiemajima_NeckBreakAbility then return end -- already breaking
        local aim_ent = NeckSnap_Trace(ply, 85).Entity
        if not NeckSnap_CanBreak(ply, aim_ent) then return end
        local victim = NeckSnap_GetTarget(aim_ent)
        ply.Expiemajima_NeckBreakAbility = {
            Victim = victim,
            AimEnt = aim_ent,
        }
        victim.Expiemajima_BeingVictimOfNeckBreak = true
        net.Start("expiemajima_neckbreak_start")
        net.Send(ply)
    end)
    net.Receive("expiemajima_neckbreak_stop", function(len, ply)
        if not IsValid(ply) then return end
        local ability = ply.Expiemajima_NeckBreakAbility
        if ability then
            local victim = ability.Victim
            if victim then victim.Expiemajima_BeingVictimOfNeckBreak = false end
        end
        ply.Expiemajima_NeckBreakAbility = nil
        net.Start("expiemajima_neckbreak_stop")
        net.Send(ply)
    end)
end
if CLIENT then
    local function draw_shadow_text(text, cx, cy)
        local shadow_color = Color(0, 0, 0, 255)
        local main_color = Color(150, 50, 0, 255)
        draw.DrawText(text, "HomigradFontMedium", cx + 1, cy + 1, shadow_color, TEXT_ALIGN_CENTER)
        draw.DrawText(text, "HomigradFontMedium", cx, cy, main_color, TEXT_ALIGN_CENTER)
    end
    hook.Add("HUDPaint", "expiemajima_neckbreak_hud", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        if ply.PlayerClassName ~= "expiemajima" then return end
        local tr = NeckSnap_Trace(ply, 85)
        if not tr then return end
        local aim_ent = tr.Entity
        local can_break = NeckSnap_CanBreak(ply, aim_ent)
        if ply:KeyDown(IN_WALK) then
            local text = "(HOLD)[ALT + E] Break Neck"
            local tw, th = surface.GetTextSize(text)
            local cx, cy = tr.HitPos:ToScreen().x, tr.HitPos:ToScreen().y
            cy = cy + 30 + ScreenScale(15)
            if can_break or ply.Expiemajima_NeckBreakProgress then
                draw_shadow_text(text, cx, cy)
                if ply.Expiemajima_NeckBreakProgress then
                    local frac = math.min(ply.Expiemajima_NeckBreakProgress / 100, 1)
                    surface.SetDrawColor(Color(150, 50, 0, 255))
                    surface.DrawRect(cx - tw / 2, cy, tw * frac, th)
                end
            end
        end
    end)
    hook.Add("Think", "expiemajima_neckbreak_think", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or ply.PlayerClassName ~= "expiemajima" then return end
        if not ply:Alive() then
            ply.Expiemajima_NeckBreakProgress = nil
            ply.Expiemajima_NeckBreakActive = nil
            return
        end
        local aim_ent = NeckSnap_Trace(ply, 85).Entity
        local can_break = NeckSnap_CanBreak(ply, aim_ent)
        local breaking = ply.Expiemajima_NeckBreakActive
        if ply:KeyDown(IN_WALK) and ply:KeyDown(IN_USE) and can_break and not breaking then
            net.Start("expiemajima_neckbreak_start")
            net.SendToServer()
            ply.Expiemajima_NeckBreakActive = true
            ply.Expiemajima_NeckBreakProgress = 0
        elseif breaking then
            if ply:KeyDown(IN_WALK) and ply:KeyDown(IN_USE) then
                if can_break then
                    ply.Expiemajima_NeckBreakProgress = math.min((ply.Expiemajima_NeckBreakProgress or 0) + FrameTime() * 300, 100)
                    if ply.Expiemajima_NeckBreakProgress >= 100 then
                        net.Start("expiemajima_neckbreak_complete")
                        net.SendToServer()
                        ply.Expiemajima_NeckBreakActive = nil
                        ply.Expiemajima_NeckBreakProgress = nil
                    end
                else
                    net.Start("expiemajima_neckbreak_stop")
                    net.SendToServer()
                    ply.Expiemajima_NeckBreakActive = nil
                    ply.Expiemajima_NeckBreakProgress = nil
                end
            else
                -- Released keys, cancel
                net.Start("expiemajima_neckbreak_stop")
                net.SendToServer()
                ply.Expiemajima_NeckBreakActive = nil
                ply.Expiemajima_NeckBreakProgress = nil
            end
        end
    end)
    net.Receive("expiemajima_neckbreak_start", function()
        local ply = LocalPlayer()
        ply.Expiemajima_NeckBreakActive = true
        ply.Expiemajima_NeckBreakProgress = 0
    end)
    net.Receive("expiemajima_neckbreak_stop", function()
        local ply = LocalPlayer()
        ply.Expiemajima_NeckBreakActive = nil
        ply.Expiemajima_NeckBreakProgress = nil
    end)
end
return CLASS