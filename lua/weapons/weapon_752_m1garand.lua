SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.NPCSpawnable = true
SWEP.NPCWeaponType = "weapon_ar2"

SWEP.PrintName = "M1 Garand"
SWEP.Author = "Springfield Armory"
SWEP.Instructions = "Semi-automatic service rifle chambered in .30-06 Springfield"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10

-- Keep the same pattern as working Z-City/Homigrad guns: fake first-person model.
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_blast_m1garand.mdl"
SWEP.WorldModelFake = "models/weapons/c_rif_blast_m1garand.mdl"
SWEP.FakeVPShouldUseHand = false

SWEP.FakePos = Vector(-12.2303, 1.9549, 5.5049)
SWEP.FakeAng = Angle(-1.4187, -0.6, 0)
SWEP.AttachmentPos = Vector(0.6, 0.1, 0.3)
SWEP.AttachmentAng = Angle(0, -2.0, 0)
SWEP.FakeEjectBrassATT = "2"

SWEP.AnimList = {
    ["idle"] = "idle",
    ["reload"] = "reload",
    ["reload_empty"] = "reload_empty",
}

SWEP.ScrappersSlot = "Primary"
SWEP.weight = 4.2
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "762x54"
SWEP.AutomaticDraw = true
SWEP.UseCustomWorldModel = true
SWEP.OpenBolt = true

SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 8
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "7.62x54 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 82
SWEP.Primary.Force = 82
SWEP.Primary.Wait = 0.17
SWEP.Primary.Sound = {"weapons/garand_shoot.wav", 70, 95, 105}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/ak47/handling/ak47_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.DistSound = "weapons/garand_shoot.wav"

SWEP.ReloadTime = 3.2
-- ReloadSoundes intentionally empty: ReloadStartPost handles all reload sounds manually
-- to avoid double-triggering and sound desync with the animation.
SWEP.ReloadSoundes = {
    "none", "none", "none", "none", "none",
    "none", "none", "none", "none", "none",
}

SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(2.018, -0.0331, 4.9623)
SWEP.RHandPos = Vector(-11, -1.4, 4.4)
SWEP.LHandPos = Vector(8.2, -1.8, -1.7)
SWEP.AimHands = Vector(-9.3, 1.2, -4.8)
SWEP.SprayRand = {Angle(0.03, -0.04, 0), Angle(-0.04, 0.03, 0)}
SWEP.Ergonomics = 0.9
SWEP.Penetration = 18
SWEP.ZoomFOV = 20
SWEP.WorldPos = Vector(7.6, -1, 1.8)
SWEP.WorldAng = Angle(0, -0.2, 0)
SWEP.handsAng = Angle(2, -0.5, 0)

SWEP.LocalMuzzlePos = Vector(29.5143, -0.2137, 4.2285)
SWEP.LocalMuzzleAng = Angle(-0.4869, -0.74, -0.36)
SWEP.TraceAngOffset = Angle(13.4641, -5.5, 0)
SWEP.GarandTraceMultiplier = 11.2537
SWEP.GarandUseADSTrace = true
SWEP.GarandEnableTraceOffset = true
SWEP.WeaponEyeAngles = Angle(0, 0, 0)
SWEP.ShockMultiplier = 2

SWEP.availableAttachments = {
    barrel = {
        [1] = {"supressor8", Vector(0, 0, 0), {}},
        ["mount"] = Vector(0.7, -0.25, -0.3),
    },
    sight = {
        ["mountType"] = {"kar98mount"},
        ["mount"] = { ["kar98mount"] = Vector(-21, 2.2, -0.1) },
    },
}

SWEP.GarandPingSound = "weapons/garand_clipding.wav"

SWEP.AnimFallbacks = {
    idle = {"idle", "base_idle", "draw", "idle_all", "idle1"},
    reload = {"reload", "base_reload", "reload_empty", "reload_clip", "reload1"},
    reload_empty = {"reload_empty", "reload", "base_reload_empty", "base_reload", "reload_clip", "reload1"},
}

function SWEP:ResolveAnimSequence(anim)
    local wm = self.GetWM and self:GetWM() or nil
    if not IsValid(wm) then return (self.AnimList and self.AnimList[anim]) or anim end

    local candidates = {}
    local mapped = self.AnimList and self.AnimList[anim]
    if isstring(mapped) and mapped ~= "" then table.insert(candidates, mapped) end
    if isstring(anim) and anim ~= "" then table.insert(candidates, anim) end

    local extra = self.AnimFallbacks and self.AnimFallbacks[anim]
    if istable(extra) then
        for _, seq in ipairs(extra) do
            if isstring(seq) and seq ~= "" then table.insert(candidates, seq) end
        end
    end

    for _, seq in ipairs(candidates) do
        local idx = wm:LookupSequence(seq)
        if idx and idx >= 0 then
            return seq
        end
    end

    return mapped or anim
end

function SWEP:PlayAnim(anim, data, cycling, callback, reverse, sendtoclient)
    -- Suppress idle while bolt is locked open; Think() maintains the frozen pose.
    if CLIENT and self.GarandBoltOpen and anim == "idle" and not self.reload then
        return
    end

    local resolved = self:ResolveAnimSequence(anim)
    return self.BaseClass.PlayAnim(self, resolved, data, cycling, callback, reverse, sendtoclient)
end

function SWEP:Think()
    if CLIENT then
        local wm = self:GetWM()
        if IsValid(wm) and self.GarandBoltOpen and not self.reload then
            -- Cache the sequence index once (uses the same fallback chain as ResolveAnimSequence).
            if self.GarandBoltSeq == nil then
                local r = self:ResolveAnimSequence("reload_empty")
                local idx = wm:LookupSequence(r)
                if idx < 0 then
                    r = self:ResolveAnimSequence("reload")
                    idx = wm:LookupSequence(r)
                end
                self.GarandBoltSeq = idx  -- may be -1 if model has no usable sequence
            end
            if self.GarandBoltSeq >= 0 then
                -- Continuously force frame 0 of the reload sequence (bolt locked back).
                if wm:GetSequence() ~= self.GarandBoltSeq or wm:GetPlaybackRate() ~= 0 then
                    wm:SetSequence(self.GarandBoltSeq)
                    wm:SetCycle(0)
                    wm:SetPlaybackRate(0)
                end
            end
        end
    end
    return self.BaseClass.Think(self)
end

function SWEP:GetTraceTuneAngles()
    local base = self.TraceAngOffset or angle_zero
    local pitch = self.GarandTracePitch
    local yaw = self.GarandTraceYaw
    local owner = self:GetOwner()

    if pitch == nil then
        pitch = self:GetNWFloat("GarandTracePitch", base[1] or 0)
        if pitch == (base[1] or 0) and IsValid(owner) then
            pitch = owner:GetNWFloat("GarandTracePitch", pitch)
        end
    end
    if yaw == nil then
        yaw = self:GetNWFloat("GarandTraceYaw", base[2] or 0)
        if yaw == (base[2] or 0) and IsValid(owner) then
            yaw = owner:GetNWFloat("GarandTraceYaw", yaw)
        end
    end

    return pitch or 0, yaw or 0
end

function SWEP:GetTrace(bCacheTrace, desiredPos, desiredAng, NoTrace, closeanim)
    local owner = self:GetOwner()
    local isAiming = (self.IsZoom and self:IsZoom()) or self:GetNWBool("aiming", false)
    local useADSTrace = self.GarandUseADSTrace

    if useADSTrace == nil then
        useADSTrace = self:GetNWBool("GarandUseADSTrace", true)
    end

    if IsValid(owner) and owner:IsPlayer() and isAiming and useADSTrace then
        local _, pos, ang = self.BaseClass.GetTrace(self, true, desiredPos, desiredAng, true, closeanim)
        if not pos or not ang then
            return self.BaseClass.GetTrace(self, bCacheTrace, desiredPos, desiredAng, NoTrace, closeanim)
        end

        local useTraceOffset = self.GarandEnableTraceOffset
        if useTraceOffset == nil then
            useTraceOffset = self:GetNWBool("GarandEnableTraceOffset", true)
        end

        if useTraceOffset then
            local pitchTune, yawTune = self:GetTraceTuneAngles()
            local traceMul = self.GarandTraceMultiplier

            if traceMul == nil then
                traceMul = self:GetNWFloat("GarandTraceMultiplier", 1)
            end

            traceMul = math.Clamp(tonumber(traceMul) or 1, 0.1, 20)

            if pitchTune ~= 0 then
                ang:RotateAroundAxis(ang:Right(), pitchTune * traceMul)
            end
            if yawTune ~= 0 then
                ang:RotateAroundAxis(ang:Up(), yawTune * traceMul)
            end
        end

        if NoTrace then
            if bCacheTrace then
                self.cache_trace = self.cache_trace or {}
                self.cache_trace[2] = pos
                self.cache_trace[3] = ang
                return pos, ang
            end
            return {}, pos, ang
        end

        local gun = self:GetWeaponEntity()
        local fake = CLIENT and owner.FakeRagdoll or nil
        local tr = {
            start = pos,
            endpos = pos + ang:Forward() * 8000,
            filter = {self, gun, not owner.suiciding and owner or NULL, not owner.suiciding and fake}
        }
        local trace = util.TraceLine(tr)

        if bCacheTrace then
            self.cache_trace = self.cache_trace or {}
            self.cache_trace[1] = trace
            self.cache_trace[2] = pos
            self.cache_trace[3] = ang
        end

        return trace, pos, ang
    end

    return self.BaseClass.GetTrace(self, bCacheTrace, desiredPos, desiredAng, NoTrace, closeanim)
end

function SWEP:PrimaryShootPost()
    if self:Clip1() <= 0 and not self.GarandPingPlayed then
        self.GarandPingPlayed = true
        if SERVER then
            self:PlaySnd(self.GarandPingSound, true, CHAN_AUTO)
        end
        -- Signal the client to lock the bolt open visually.
        self.GarandBoltOpen = true
    end
end

function SWEP:PrimaryShootEmpty()
    if CLIENT then return end
    self:PlaySnd(self.Primary.SoundEmpty, true, CHAN_AUTO)
end

function SWEP:CanReload()
    local baseCanReload = true
    if self.BaseClass and self.BaseClass.CanReload then
        baseCanReload = self.BaseClass.CanReload(self)
    end
    if not baseCanReload then return false end
    if self:Clip1() > 0 then return false end
    return true
end

if SERVER then
    function SWEP:Reload(time)
        if self.reload then return end
        if IsValid(self:GetOwner().FakeRagdoll) and self:GetOwner().FakeRagdoll.ConsLH then return end
        if not self:CanUse() or not self:CanReload() then self:OnCantReload() return end

        self.LastReload = CurTime()
        self:ReloadStart()

        self.StaminaReloadMul = 1
        self.StaminaReloadTime = self.ReloadTime
        self.reload = self.LastReload + self.StaminaReloadTime
        self:ReloadStartPost()
        self.dwr_reverbDisable = true

        net.Start("hgwep reload")
            net.WriteEntity(self)
            net.WriteFloat(self.LastReload)
            net.WriteInt(self:Clip1(),10)
            net.WriteFloat(self.StaminaReloadTime)
            net.WriteFloat(self.StaminaReloadMul)
        net.Broadcast()
    end
else
    function SWEP:Reload(time)
        if not time then return end
        if not self:CanReload() then return end

        -- Release the bolt freeze so the reload animation can play.
        self.GarandBoltOpen = false
        local wm = self:GetWM()
        if IsValid(wm) then wm:SetPlaybackRate(1) end

        self.LastReload = time
        self:ReloadStart()

        self.StaminaReloadMul = 1
        self.StaminaReloadTime = self.ReloadTime
        self.reload = time + self.StaminaReloadTime
        if self:ShouldUseFakeModel() then
            self:PlayAnim(self:Clip1() == 0 and "reload_empty" or "reload", self.StaminaReloadTime, false, function()
                self:PlayAnim("idle", 1, not self.NoIdleLoop)
            end)
        end
        self:Step_Reload(CurTime() - 1)
        self.dwr_reverbDisable = true
    end
end

function SWEP:ReloadStartPost()
    if not SERVER then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local rt = self.StaminaReloadTime or self.ReloadTime or 3.2

    timer.Simple(rt * 0.18, function()
        if not IsValid(self) or not IsValid(owner) or not self.reload then return end
        owner:EmitSound("weapons/garand_clipin1.wav", 62, 100, 0.75, CHAN_AUTO)
    end)

    timer.Simple(rt * 0.44, function()
        if not IsValid(self) or not IsValid(owner) or not self.reload then return end
        owner:EmitSound("weapons/garand_clipin2.wav", 62, 100, 0.75, CHAN_AUTO)
    end)

    timer.Simple(rt * 0.68, function()
        if not IsValid(self) or not IsValid(owner) or not self.reload then return end
        owner:EmitSound("weapons/garand_boltforward.wav", 62, 100, 0.75, CHAN_AUTO)
    end)
end

function SWEP:ReloadEnd()
    if self.BaseClass and self.BaseClass.ReloadEnd then
        self.BaseClass.ReloadEnd(self)
    else
        self:InsertAmmo(self:GetMaxClip1() - self:Clip1())
    end
    self.GarandPingPlayed = false
    self.GarandBoltOpen = false
end

if SERVER then
    util.AddNetworkString("hg_garand_tuner_apply")

    local function ClampNum(v, minV, maxV, defaultV)
        v = tonumber(v)
        if v == nil then v = defaultV or 0 end
        return math.Clamp(v, minV, maxV)
    end

    local function ApplyGarandConfig(ply, cfg)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        if not ply:IsAdmin() and not game.SinglePlayer() then return false end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_752_m1garand" then return false end

        cfg = istable(cfg) and cfg or {}

        wep.ZoomPos = Vector(
            ClampNum(cfg.zoom_x, -64, 64, wep.ZoomPos[1]),
            ClampNum(cfg.zoom_y, -64, 64, wep.ZoomPos[2]),
            ClampNum(cfg.zoom_z, -64, 64, wep.ZoomPos[3])
        )

        wep.FakePos = Vector(
            ClampNum(cfg.fakepos_x, -64, 64, wep.FakePos[1]),
            ClampNum(cfg.fakepos_y, -64, 64, wep.FakePos[2]),
            ClampNum(cfg.fakepos_z, -64, 64, wep.FakePos[3])
        )

        wep.FakeAng = Angle(
            ClampNum(cfg.fakeang_p, -180, 180, wep.FakeAng[1]),
            ClampNum(cfg.fakeang_y, -180, 180, wep.FakeAng[2]),
            ClampNum(cfg.fakeang_r, -180, 180, wep.FakeAng[3])
        )

        wep.AttachmentPos = Vector(
            ClampNum(cfg.attpos_x, -32, 32, wep.AttachmentPos[1]),
            ClampNum(cfg.attpos_y, -32, 32, wep.AttachmentPos[2]),
            ClampNum(cfg.attpos_z, -32, 32, wep.AttachmentPos[3])
        )

        wep.AttachmentAng = Angle(
            ClampNum(cfg.attang_p, -180, 180, wep.AttachmentAng[1]),
            ClampNum(cfg.attang_y, -180, 180, wep.AttachmentAng[2]),
            ClampNum(cfg.attang_r, -180, 180, wep.AttachmentAng[3])
        )

        wep.LocalMuzzlePos = Vector(
            ClampNum(cfg.muzzlepos_x, -64, 64, wep.LocalMuzzlePos[1]),
            ClampNum(cfg.muzzlepos_y, -64, 64, wep.LocalMuzzlePos[2]),
            ClampNum(cfg.muzzlepos_z, -64, 64, wep.LocalMuzzlePos[3])
        )

        wep.LocalMuzzleAng = Angle(
            ClampNum(cfg.muzzleang_p, -180, 180, wep.LocalMuzzleAng[1]),
            ClampNum(cfg.muzzleang_y, -180, 180, wep.LocalMuzzleAng[2]),
            ClampNum(cfg.muzzleang_r, -180, 180, wep.LocalMuzzleAng[3])
        )

        local pitch = ClampNum(cfg.trace_pitch, -30, 30, wep.TraceAngOffset[1])
        local yaw = ClampNum(cfg.trace_yaw, -30, 30, wep.TraceAngOffset[2])
        local traceMul = ClampNum(cfg.trace_mul, 0.1, 20, wep.GarandTraceMultiplier or 1)

        wep.TraceAngOffset = Angle(pitch, yaw, 0)
        wep.GarandTracePitch = pitch
        wep.GarandTraceYaw = yaw
        wep.GarandTraceMultiplier = traceMul

        wep.GarandUseADSTrace = cfg.use_ads_trace ~= false
        wep.GarandEnableTraceOffset = cfg.use_trace_offset ~= false

        wep:SetNWFloat("GarandTracePitch", pitch)
        wep:SetNWFloat("GarandTraceYaw", yaw)
        wep:SetNWFloat("GarandTraceMultiplier", traceMul)
        wep:SetNWBool("GarandUseADSTrace", wep.GarandUseADSTrace)
        wep:SetNWBool("GarandEnableTraceOffset", wep.GarandEnableTraceOffset)
        ply:SetNWFloat("GarandTracePitch", pitch)
        ply:SetNWFloat("GarandTraceYaw", yaw)
        ply:SetNWFloat("GarandTraceMultiplier", traceMul)

        return true
    end

    net.Receive("hg_garand_tuner_apply", function(_, ply)
        local cfg = net.ReadTable() or {}
        ApplyGarandConfig(ply, cfg)
    end)

    concommand.Remove("hg_garand_zero_sv")
    concommand.Add("hg_garand_zero_sv", function(ply, _, args)
        if not IsValid(ply) then return end
        ApplyGarandConfig(ply, {
            trace_pitch = tonumber(args[1]) or 0,
            trace_yaw = tonumber(args[2]) or 0,
            trace_mul = 6,
        })
    end)
else
    local function GetHeldGarand()
        local ply = LocalPlayer()
        if not IsValid(ply) then return nil end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_752_m1garand" then
            return nil
        end

        return wep
    end

    local function GetGarandTune(wep)
        local base = wep.TraceAngOffset or angle_zero
        local pitch = wep.GarandTracePitch
        local yaw = wep.GarandTraceYaw

        if pitch == nil then pitch = wep:GetNWFloat("GarandTracePitch", base[1] or 0) end
        if yaw == nil then yaw = wep:GetNWFloat("GarandTraceYaw", base[2] or 0) end

        return pitch or 0, yaw or 0
    end

    local function ApplyGarandTune(wep, pitch, yaw)
        pitch = math.Clamp(pitch or 0, -15, 15)
        yaw = math.Clamp(yaw or 0, -15, 15)

        wep.GarandTracePitch = pitch
        wep.GarandTraceYaw = yaw

        RunConsoleCommand("hg_garand_zero_sv", tostring(pitch), tostring(yaw))
    end

    local function BuildGarandConfigFromWeapon(wep)
        local tracePitch, traceYaw = GetGarandTune(wep)

        return {
            zoom_x = wep.ZoomPos[1],
            zoom_y = wep.ZoomPos[2],
            zoom_z = wep.ZoomPos[3],

            fakepos_x = wep.FakePos[1],
            fakepos_y = wep.FakePos[2],
            fakepos_z = wep.FakePos[3],

            fakeang_p = wep.FakeAng[1],
            fakeang_y = wep.FakeAng[2],
            fakeang_r = wep.FakeAng[3],

            attpos_x = wep.AttachmentPos[1],
            attpos_y = wep.AttachmentPos[2],
            attpos_z = wep.AttachmentPos[3],

            attang_p = wep.AttachmentAng[1],
            attang_y = wep.AttachmentAng[2],
            attang_r = wep.AttachmentAng[3],

            muzzlepos_x = wep.LocalMuzzlePos[1],
            muzzlepos_y = wep.LocalMuzzlePos[2],
            muzzlepos_z = wep.LocalMuzzlePos[3],

            muzzleang_p = wep.LocalMuzzleAng[1],
            muzzleang_y = wep.LocalMuzzleAng[2],
            muzzleang_r = wep.LocalMuzzleAng[3],

            trace_pitch = tracePitch,
            trace_yaw = traceYaw,
            trace_mul = math.Clamp(tonumber(wep.GarandTraceMultiplier) or 1, 0.1, 20),

            use_ads_trace = wep.GarandUseADSTrace ~= false,
            use_trace_offset = wep.GarandEnableTraceOffset ~= false,
        }
    end

    local function ApplyGarandConfigLocal(wep, cfg)
        wep.ZoomPos = Vector(cfg.zoom_x, cfg.zoom_y, cfg.zoom_z)
        wep.FakePos = Vector(cfg.fakepos_x, cfg.fakepos_y, cfg.fakepos_z)
        wep.FakeAng = Angle(cfg.fakeang_p, cfg.fakeang_y, cfg.fakeang_r)
        wep.AttachmentPos = Vector(cfg.attpos_x, cfg.attpos_y, cfg.attpos_z)
        wep.AttachmentAng = Angle(cfg.attang_p, cfg.attang_y, cfg.attang_r)
        wep.LocalMuzzlePos = Vector(cfg.muzzlepos_x, cfg.muzzlepos_y, cfg.muzzlepos_z)
        wep.LocalMuzzleAng = Angle(cfg.muzzleang_p, cfg.muzzleang_y, cfg.muzzleang_r)

        wep.GarandTracePitch = cfg.trace_pitch
        wep.GarandTraceYaw = cfg.trace_yaw
        wep.TraceAngOffset = Angle(cfg.trace_pitch, cfg.trace_yaw, 0)
        wep.GarandTraceMultiplier = cfg.trace_mul

        wep.GarandUseADSTrace = cfg.use_ads_trace ~= false
        wep.GarandEnableTraceOffset = cfg.use_trace_offset ~= false
    end

    local function SendGarandConfig(cfg)
        net.Start("hg_garand_tuner_apply")
            net.WriteTable(cfg)
        net.SendToServer()
    end

    local function PrintGarandConfig(cfg)
        local lines = {
            string.format("SWEP.ZoomPos = Vector(%.4f, %.4f, %.4f)", cfg.zoom_x, cfg.zoom_y, cfg.zoom_z),
            string.format("SWEP.FakePos = Vector(%.4f, %.4f, %.4f)", cfg.fakepos_x, cfg.fakepos_y, cfg.fakepos_z),
            string.format("SWEP.FakeAng = Angle(%.4f, %.4f, %.4f)", cfg.fakeang_p, cfg.fakeang_y, cfg.fakeang_r),
            string.format("SWEP.AttachmentPos = Vector(%.4f, %.4f, %.4f)", cfg.attpos_x, cfg.attpos_y, cfg.attpos_z),
            string.format("SWEP.AttachmentAng = Angle(%.4f, %.4f, %.4f)", cfg.attang_p, cfg.attang_y, cfg.attang_r),
            string.format("SWEP.LocalMuzzlePos = Vector(%.4f, %.4f, %.4f)", cfg.muzzlepos_x, cfg.muzzlepos_y, cfg.muzzlepos_z),
            string.format("SWEP.LocalMuzzleAng = Angle(%.4f, %.4f, %.4f)", cfg.muzzleang_p, cfg.muzzleang_y, cfg.muzzleang_r),
            string.format("SWEP.TraceAngOffset = Angle(%.4f, %.4f, 0)", cfg.trace_pitch, cfg.trace_yaw),
            string.format("SWEP.GarandTraceMultiplier = %.4f", cfg.trace_mul),
            string.format("SWEP.GarandUseADSTrace = %s", cfg.use_ads_trace and "true" or "false"),
            string.format("SWEP.GarandEnableTraceOffset = %s", cfg.use_trace_offset and "true" or "false"),
        }

        local out = table.concat(lines, "\n")
        print(out)
        SetClipboardText(out .. "\n")
    end

    local garandTunerDefaults = {
        zoom_x = 2.018,
        zoom_y = -0.0331,
        zoom_z = 4.9623,
        fakepos_x = -12.2303,
        fakepos_y = 1.9549,
        fakepos_z = 5.5049,
        fakeang_p = -1.4187,
        fakeang_y = -0.6,
        fakeang_r = 0,
        attpos_x = 0.6,
        attpos_y = 0.1,
        attpos_z = 0.3,
        attang_p = 0,
        attang_y = -2.0,
        attang_r = 0,
        muzzlepos_x = 29.5143,
        muzzlepos_y = -0.2137,
        muzzlepos_z = 4.2285,
        muzzleang_p = -0.4869,
        muzzleang_y = -0.74,
        muzzleang_r = -0.36,
        trace_pitch = 13.4641,
        trace_yaw = -5.5,
        trace_mul = 11.2537,
        use_ads_trace = true,
        use_trace_offset = true,
        show_hit_debug = false,
        set_zoom_mode = false,
    }

    concommand.Remove("hg_garand_tuner")
    concommand.Add("hg_garand_tuner", function()
        local wep = GetHeldGarand()
        if not IsValid(wep) then
            print("hg_garand_tuner: hold weapon_752_m1garand first")
            return
        end

        local state = BuildGarandConfigFromWeapon(wep)
        state.show_hit_debug = GetConVar("hg_show_hitposmuzzle") and GetConVar("hg_show_hitposmuzzle"):GetBool() or false
        state.set_zoom_mode = GetConVar("hg_setzoompos") and GetConVar("hg_setzoompos"):GetBool() or false
        local debounceId = "hg_garand_tuner_apply_" .. LocalPlayer():EntIndex()

        local function QueueApply()
            timer.Create(debounceId, 0.03, 1, function()
                local held = GetHeldGarand()
                if not IsValid(held) then return end
                ApplyGarandConfigLocal(held, state)
                SendGarandConfig(state)
            end)
        end

        local frame = vgui.Create("DFrame")
        frame:SetSize(520, 760)
        frame:Center()
        frame:SetTitle("M1 Garand Live Tuner")
        frame:MakePopup()

        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(6, 6, 6, 6)

        local function AddSlider(label, key, minV, maxV, decimals)
            local s = scroll:Add("DNumSlider")
            s:Dock(TOP)
            s:DockMargin(0, 0, 0, 6)
            s:SetText(label)
            s:SetMinMax(minV, maxV)
            s:SetDecimals(decimals)
            s:SetValue(state[key] or 0)
            function s:OnValueChanged(value)
                state[key] = tonumber(value) or 0

                if string.sub(key, 1, 5) == "zoom_" and state.set_zoom_mode then
                    state.set_zoom_mode = false
                    RunConsoleCommand("hg_setzoompos", "0")
                end

                QueueApply()
            end
        end

        local function AddCheck(label, key, onChanged)
            local c = scroll:Add("DCheckBoxLabel")
            c:Dock(TOP)
            c:DockMargin(0, 0, 0, 6)
            c:SetText(label)
            c:SetValue(state[key] and 1 or 0)
            c:SizeToContents()
            function c:OnChange(val)
                state[key] = val and true or false
                if onChanged then onChanged(state[key]) end
                QueueApply()
            end
        end

        AddCheck("Use ADS trace override", "use_ads_trace")
        AddCheck("Apply TraceAngOffset", "use_trace_offset")
        AddCheck("Show hitpos/muzzle debug", "show_hit_debug", function(val)
            RunConsoleCommand("hg_show_hitposmuzzle", val and "1" or "0")
        end)
        AddCheck("Enable hg_setzoompos mode", "set_zoom_mode", function(val)
            RunConsoleCommand("hg_setzoompos", val and "1" or "0")
        end)

        AddSlider("Trace Pitch", "trace_pitch", -30, 30, 3)
        AddSlider("Trace Yaw", "trace_yaw", -30, 30, 3)
        AddSlider("Trace Multiplier", "trace_mul", 0.1, 20, 3)

        AddSlider("ZoomPos X", "zoom_x", -64, 64, 4)
        AddSlider("ZoomPos Y", "zoom_y", -64, 64, 4)
        AddSlider("ZoomPos Z", "zoom_z", -64, 64, 4)

        AddSlider("FakePos X", "fakepos_x", -64, 64, 4)
        AddSlider("FakePos Y", "fakepos_y", -64, 64, 4)
        AddSlider("FakePos Z", "fakepos_z", -64, 64, 4)

        AddSlider("FakeAng Pitch", "fakeang_p", -180, 180, 3)
        AddSlider("FakeAng Yaw", "fakeang_y", -180, 180, 3)
        AddSlider("FakeAng Roll", "fakeang_r", -180, 180, 3)

        AddSlider("AttachmentPos X", "attpos_x", -32, 32, 4)
        AddSlider("AttachmentPos Y", "attpos_y", -32, 32, 4)
        AddSlider("AttachmentPos Z", "attpos_z", -32, 32, 4)

        AddSlider("AttachmentAng Pitch", "attang_p", -180, 180, 3)
        AddSlider("AttachmentAng Yaw", "attang_y", -180, 180, 3)
        AddSlider("AttachmentAng Roll", "attang_r", -180, 180, 3)

        AddSlider("LocalMuzzlePos X", "muzzlepos_x", -64, 64, 4)
        AddSlider("LocalMuzzlePos Y", "muzzlepos_y", -64, 64, 4)
        AddSlider("LocalMuzzlePos Z", "muzzlepos_z", -64, 64, 4)

        AddSlider("LocalMuzzleAng Pitch", "muzzleang_p", -180, 180, 3)
        AddSlider("LocalMuzzleAng Yaw", "muzzleang_y", -180, 180, 3)
        AddSlider("LocalMuzzleAng Roll", "muzzleang_r", -180, 180, 3)

        local btnRow = scroll:Add("DPanel")
        btnRow:Dock(TOP)
        btnRow:DockMargin(0, 4, 0, 0)
        btnRow:SetTall(30)

        local btnPrint = vgui.Create("DButton", btnRow)
        btnPrint:Dock(LEFT)
        btnPrint:SetWide(170)
        btnPrint:SetText("Print + Copy Config")
        btnPrint.DoClick = function()
            PrintGarandConfig(state)
        end

        local btnReset = vgui.Create("DButton", btnRow)
        btnReset:Dock(LEFT)
        btnReset:DockMargin(6, 0, 0, 0)
        btnReset:SetWide(130)
        btnReset:SetText("Reset Defaults")
        btnReset.DoClick = function()
            for k, v in pairs(garandTunerDefaults) do
                state[k] = v
            end
            local held = GetHeldGarand()
            if IsValid(held) then
                ApplyGarandConfigLocal(held, state)
            end
            SendGarandConfig(state)
            frame:Close()
            RunConsoleCommand("hg_garand_tuner")
        end

        local btnApply = vgui.Create("DButton", btnRow)
        btnApply:Dock(FILL)
        btnApply:DockMargin(6, 0, 0, 0)
        btnApply:SetText("Apply Now")
        btnApply.DoClick = function()
            local held = GetHeldGarand()
            if IsValid(held) then
                ApplyGarandConfigLocal(held, state)
            end
            SendGarandConfig(state)
        end

        frame.OnClose = function()
            timer.Remove(debounceId)
        end
    end)

    local function PrintGarandTune(pitch, yaw)
        local str = string.format("SWEP.TraceAngOffset = Angle(%.4f, %.4f, 0)", pitch, yaw)
        print(str)
        SetClipboardText(str .. "\n")
    end

    concommand.Remove("hg_garand_zero")
    concommand.Add("hg_garand_zero", function(_, _, args)
        local wep = GetHeldGarand()
        if not IsValid(wep) then
            print("hg_garand_zero: hold weapon_752_m1garand first")
            return
        end

        local mode = string.lower(args[1] or "print")
        local delta = tonumber(args[2]) or 0.02

        local pitch, yaw = GetGarandTune(wep)

        if mode == "pitch" then
            pitch = pitch + delta
        elseif mode == "yaw" then
            yaw = yaw + delta
        elseif mode == "set" then
            pitch = tonumber(args[2]) or pitch
            yaw = tonumber(args[3]) or yaw
        elseif mode == "reset" then
            pitch = (wep.TraceAngOffset and wep.TraceAngOffset[1]) or 0
            yaw = (wep.TraceAngOffset and wep.TraceAngOffset[2]) or 0
        elseif mode == "print" then
            PrintGarandTune(pitch, yaw)
            print("hg_garand_zero usage: pitch <step> | yaw <step> | set <pitch> <yaw> | reset | print")
            return
        else
            print("hg_garand_zero usage: pitch <step> | yaw <step> | set <pitch> <yaw> | reset | print")
            return
        end

        ApplyGarandTune(wep, pitch, yaw)

        pitch, yaw = GetGarandTune(wep)
        print(string.format("Garand zero now pitch=%.4f yaw=%.4f", pitch, yaw))
        PrintGarandTune(pitch, yaw)
    end)
end
