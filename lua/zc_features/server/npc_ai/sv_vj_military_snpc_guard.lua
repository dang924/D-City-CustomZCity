if CLIENT then return end

-- Defensive shim for specific VJ Base military SNPCs that hard-error when
-- schedule hooks assume missing methods/state exist.
-- This is a containment patch, not a perfect behavioral fix.

local cvEnable = CreateConVar("zc_vj_military_guard", "1", FCVAR_ARCHIVE, "Enable defensive guards for fragile VJ military SNPC schedule hooks.", 0, 1)
local cvVerbose = CreateConVar("zc_vj_military_guard_verbose", "0", FCVAR_ARCHIVE, "Print when VJ military guard catches a runtime error.", 0, 1)

local patched = {}

local function LogVerbose(message)
    if cvVerbose:GetBool() then
        print(message)
    end
end

local function EnsureLegacyTankFields(self)
    if self.Tank_SeeClose == nil then
        self.Tank_SeeClose = self.Tank_Shell_FireMin or 350
    end

    if self.Tank_SeeFar == nil then
        self.Tank_SeeFar = self.Tank_Shell_FireMax or self.SightDistance or 10000
    end

    if self.Tank_SeeLimit == nil then
        self.Tank_SeeLimit = self.Tank_Shell_FireMax or self.SightDistance or 10000
    end

    if self.Tank_ResetedEnemy == nil then
        self.Tank_ResetedEnemy = false
    end

    if self.Tank_Status == nil then
        self.Tank_Status = 1
    end

    if self.Tank_GunnerIsTurning == nil then
        self.Tank_GunnerIsTurning = false
    end

    if self.Tank_FacingTarget == nil then
        self.Tank_FacingTarget = false
    end

    if self.Tank_ProperHeightShoot == nil then
        self.Tank_ProperHeightShoot = false
    end

    if self.FiringShell == nil then
        self.FiringShell = false
    end
end

local function ValidateLegacyChildState(self)
    if not IsValid(self) then return false end

    EnsureLegacyTankFields(self)

    local parent = self:GetParent()
    if not IsValid(parent) then
        self:SetEnemy(NULL)
        self.Tank_Status = 1
        self.Tank_GunnerIsTurning = false
        self.FiringShell = false
        return false
    end

    if istable(parent.VJ_NPC_Class) then
        self.VJ_NPC_Class = parent.VJ_NPC_Class
    end

    if parent.SquadName ~= nil then
        self.SquadName = parent.SquadName
    end

    if parent.PlayerFriendly ~= nil then
        self.PlayerFriendly = parent.PlayerFriendly
    end

    if parent.FriendsWithAllPlayerAllies ~= nil then
        self.FriendsWithAllPlayerAllies = parent.FriendsWithAllPlayerAllies
    end

    local enemy = parent:GetEnemy()
    if IsValid(enemy) then
        self:SetEnemy(enemy)
    else
        self:SetEnemy(NULL)
    end

    return true
end

local function WrapScheduleMethod(entTbl, className)
    local original = entTbl.CustomOnSchedule

    entTbl.CustomOnSchedule = function(self, ...)
        if cvEnable:GetBool() then
            EnsureLegacyTankFields(self)
        end

        if type(original) ~= "function" then
            local enemy = self:GetEnemy()
            if not IsValid(enemy) then
                self.Tank_Status = 1
                if self.Tank_ResetedEnemy == false and type(self.ResetEnemy) == "function" then
                    self.Tank_ResetedEnemy = true
                    pcall(self.ResetEnemy, self)
                end
                return nil
            end

            self.Tank_ResetedEnemy = false
            local enemyPosToSelf = self:GetPos():Distance(enemy:GetPos())
            if enemyPosToSelf > self.Tank_SeeLimit then
                self.Tank_Status = 1
            elseif enemyPosToSelf < self.Tank_SeeFar and enemyPosToSelf > self.Tank_SeeClose then
                self.Tank_Status = 0
            else
                self.Tank_Status = 1
            end

            return nil
        end

        local ok, result = xpcall(original, debug.traceback, self, ...)
        if ok then
            return result
        end

        LogVerbose(string.format("[DCityPatch] VJ guard caught %s:CustomOnSchedule error: %s", className, tostring(result)))
        return nil
    end
end

local function GuardLegacyThink(entTbl, className, methodName)
    local original = entTbl[methodName]
    if type(original) ~= "function" then return false end

    entTbl[methodName] = function(self, ...)
        if cvEnable:GetBool() and not ValidateLegacyChildState(self) then
            return nil
        end

        local ok, result = xpcall(original, debug.traceback, self, ...)
        if ok then
            return result
        end

        LogVerbose(string.format("[DCityPatch] VJ guard caught %s:%s error: %s", className, methodName, tostring(result)))
        return nil
    end

    return true
end

local function WrapFireLightMethod(entTbl, className, methodName)
    local original = entTbl[methodName]
    if type(original) ~= "function" then return false end

    entTbl[methodName] = function(self, ...)
        local ok, result = xpcall(original, debug.traceback, self, ...)
        if not ok then
            LogVerbose(string.format("[DCityPatch] VJ guard caught %s:%s error: %s", className, methodName, tostring(result)))
            return nil
        end

        local fireLight = self.FireLight1
        if IsValid(fireLight) then
            self.FireLight1 = {
                Remove = function()
                    if IsValid(fireLight) then
                        fireLight:Remove()
                    end
                end
            }
        end

        return result
    end

    return true
end

local function EnsureMethod(entTbl, methodName, fallback)
    if type(entTbl[methodName]) ~= "function" then
        entTbl[methodName] = fallback or function() end
        return true
    end

    return false
end

local function WrapParentedChildSchedule(entTbl, className)
    local original = entTbl.SelectSchedule

    entTbl.SelectSchedule = function(self, ...)
        if cvEnable:GetBool() and IsValid(self:GetParent()) then
            self:SetMoveType(MOVETYPE_NONE)
            self:SetSolid(SOLID_NONE)
            self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            if self.SetNoDraw then
                self:SetNoDraw(true)
            end
            if self.DrawShadow then
                self:DrawShadow(false)
            end
            return nil
        end

        if type(original) == "function" then
            return original(self, ...)
        end

        return nil
    end

    LogVerbose(string.format("[DCityPatch] VJ guard installed parented schedule bypass for %s", className))
    return true
end

local function SpawnChildEntity(owner, className, setup)
    local ent = ents.Create(className)
    if not IsValid(ent) then
        LogVerbose(string.format("[DCityPatch] Skipped missing child entity %s for %s", className, tostring(owner)))
        return nil
    end

    setup(ent)
    ent:Spawn()
    return ent
end

local function WrapBradleyTurretInitialize(entTbl, hostile)
    entTbl.CustomInitialize = function(self)
        self:PhysicsInit(SOLID_BBOX)

        SpawnChildEntity(self, "prop_physics", function(ent)
            ent:SetModel("models/aftokinito/CoD4/American/bradley_gun.mdl")
            ent:SetPos(self:GetPos() + self:GetForward() * 24 + self:GetRight() * 0 + self:GetUp() * 15)
            ent:SetParent(self)
            ent:SetSkin(self:GetSkin())
            ent:SetAngles(self:GetAngles())
        end)

        SpawnChildEntity(self, "npc_us_bradley_atgm", function(ent)
            ent:SetModel("models/aftokinito/CoD4/American/bradley_atgm.mdl")
            ent:SetPos(self:LocalToWorld(Vector(13, 50, 19)))
            ent:SetParent(self)
            ent:SetSkin(self:GetSkin())
            ent:SetAngles(self:GetAngles())
        end)

        SpawnChildEntity(self, hostile and "npc_us_browningmg_h" or "npc_us_browningmg", function(ent)
            ent:SetPos(self:GetPos() + self:GetForward() * 125 + self:GetRight() * 20 + self:GetUp() * -37)
            ent:SetParent(self)
            ent:SetSkin(self:GetSkin())
            ent:SetLocalAngles(self:GetAngles() + Angle(0, 0, 0))
        end)

        SpawnChildEntity(self, hostile and "npc_us_25mmgun_h" or "npc_us_25mmgun", function(ent)
            ent:SetModel("")
            ent:SetPos(self:LocalToWorld(Vector(82, -7.55, -33.9)))
            ent:SetParent(self)
            ent:SetSkin(self:GetSkin())
            ent:SetAngles(self:GetAngles())
        end)
    end

    return true
end

local function WrapBrokenRapidFireScheduler(entTbl, className)
    local original = entTbl.RangeAttack_Base
    if type(original) ~= "function" then return false end

    entTbl.RangeAttack_Base = function(self, ...)
        if not cvEnable:GetBool() then
            return original(self, ...)
        end

        if not IsValid(self) or self.Dead == true then return nil end
        if self.Tank_ProperHeightShoot == false then return nil end
        if not IsValid(self:GetEnemy()) then
            self.FiringShell = false
            self.Tank_ShellReady = false
            return nil
        end

        self.zcCompatNextFire = self.zcCompatNextFire or 0
        if CurTime() < self.zcCompatNextFire or self.FiringShell == true then
            return nil
        end

        self.zcCompatNextFire = CurTime() + 1.05
        self.FiringShell = true
        self.Tank_ShellReady = true

        local timerName = "timer_shell_attack" .. self:EntIndex()
        timer.Remove(timerName)
        timer.Create(timerName, 1, 1, function()
            if not IsValid(self) then return end

            local ok, result = xpcall(function()
                return self:RangeAttack_Shell()
            end, debug.traceback)

            self.FiringShell = false
            self.Tank_ShellReady = false

            if not ok then
                LogVerbose(string.format("[DCityPatch] VJ guard caught %s:RangeAttack_Shell error: %s", className, tostring(result)))
            end
        end)

        return nil
    end

    return true
end

local function GuardMethod(entTbl, className, methodName)
    local original = entTbl[methodName]
    if type(original) ~= "function" then return false end

    entTbl[methodName] = function(self, ...)
        if not cvEnable:GetBool() then
            return original(self, ...)
        end

        local ok, result = xpcall(original, debug.traceback, self, ...)
        if ok then
            return result
        end

        LogVerbose(string.format("[DCityPatch] VJ guard caught %s:%s error: %s", className, methodName, tostring(result)))

        -- Suppress repeated hard errors; let the NPC continue existing.
        return nil
    end

    return true
end

local function PatchClass(className)
    if patched[className] then return true end

    local stored = scripted_ents.GetStored(className)
    local entTbl = stored and stored.t or nil
    if not entTbl then return false end

    if className == "npc_rf_t90mgturret_h" or className == "npc_rf_t90mgturret" or className == "npc_su_t64bv_turret_h" or className == "npc_su_t64bv_turret" or className == "npc_su_t54_turret_h" or className == "npc_su_t54_turret" or className == "npc_us_palmgtur_h" or className == "npc_us_palmgtur" or className == "npc_us_m48_turret_h" or className == "npc_us_m48_turret" or className == "npc_us_m60_turret_h" or className == "npc_us_m60_turret" or className == "npc_us_abrams_turret_h" or className == "npc_us_abrams_turret" or className == "npc_us_m103_turret_h" or className == "npc_us_m103_turret" or className == "npc_us_m1a2_turret_h" or className == "npc_us_m1a2_turret" or className == "npc_us_paladin_turret_h" or className == "npc_us_paladin_turret" then
        WrapScheduleMethod(entTbl, className)
        GuardLegacyThink(entTbl, className, "CustomOnThink_AIEnabled")
    else
        GuardMethod(entTbl, className, "CustomOnSchedule")
        GuardMethod(entTbl, className, "CustomOnThink_AIEnabled")
    end

    if className == "npc_us_bradley_h" or className == "npc_us_bradley" or className == "npc_us_m60_h" or className == "npc_us_m60" then
        EnsureMethod(entTbl, "StartSpawnEffects", function() end)
    end

    -- Several US hull classes ship with a legacy Tank_GunnerENT that spawns
    -- an unrelated Soviet ally turret before their real custom turret spawns.
    -- Clearing this keeps faction alignment consistent.
    if className == "npc_us_bradley_h" or className == "npc_us_bradley" or className == "npc_us_m24_h" or className == "npc_us_m24" or className == "npc_us_m48_h" or className == "npc_us_m48" or className == "npc_us_m60_h" or className == "npc_us_m60" or className == "npc_us_abrams_h" or className == "npc_us_abrams" or className == "npc_us_m103_h" or className == "npc_us_m103" or className == "npc_us_m1a2_h" or className == "npc_us_m1a2" or className == "npc_us_paladin_h" or className == "npc_us_paladin" then
        entTbl.Tank_GunnerENT = nil
    end

    if className == "npc_su_mg_h" or className == "npc_su_mg" or className == "npc_us_browningmg_h" or className == "npc_us_browningmg" then
        WrapParentedChildSchedule(entTbl, className)
    end

    if className == "npc_us_bradley_turret_h" then
        WrapBradleyTurretInitialize(entTbl, true)
    elseif className == "npc_us_bradley_turret" then
        WrapBradleyTurretInitialize(entTbl, false)
    end

    if className == "npc_us_m24_h" or className == "npc_us_m24" or className == "npc_us_m60_h" or className == "npc_us_m60" or className == "npc_us_m48_h" or className == "npc_us_m48" or className == "npc_us_m103_h" or className == "npc_us_m103" or className == "npc_us_m1a2_h" or className == "npc_us_m1a2" or className == "npc_us_paladin_h" or className == "npc_us_paladin" then
        EnsureMethod(entTbl, "CustomInitialize_CustomTank", function() end)
    end

    if className == "npc_us_abrams_turret_h" or className == "npc_us_abrams_turret" or className == "npc_us_m103_turret_h" or className == "npc_us_m103_turret" or className == "npc_us_m1a2_turret_h" or className == "npc_us_m1a2_turret" or className == "npc_us_paladin_turret_h" or className == "npc_us_paladin_turret" then
        EnsureMethod(entTbl, "Tank_Sound_ReloadShell", function() end)
        EnsureMethod(entTbl, "StartShootEffects", function() end)
        WrapFireLightMethod(entTbl, className, "Tank_FireShell")
    end

    if className == "npc_rf_t90mgturret_h" or className == "npc_rf_t90mgturret" then
        WrapBrokenRapidFireScheduler(entTbl, className)
        WrapFireLightMethod(entTbl, className, "RangeAttack_Shell")
    elseif className == "npc_su_t72_turret_h" or className == "npc_su_t72_turret" then
        WrapFireLightMethod(entTbl, className, "Tank_FireShell")
    end

    patched[className] = true
    print("[DCityPatch] VJ military guard installed for " .. className)
    return true
end

local function InstallGuards()
    if not cvEnable:GetBool() then return end

    PatchClass("npc_rf_t90mgturret")
    PatchClass("npc_rf_t90mgturret_h")
    PatchClass("npc_su_t54_turret")
    PatchClass("npc_su_t54_turret_h")
    PatchClass("npc_su_t64bv_turret")
    PatchClass("npc_su_t64bv_turret_h")
    PatchClass("npc_su_mg")
    PatchClass("npc_su_mg_h")
    PatchClass("npc_su_t72_turret")
    PatchClass("npc_su_t72_turret_h")
    PatchClass("npc_us_browningmg")
    PatchClass("npc_us_browningmg_h")
    PatchClass("npc_us_bradley")
    PatchClass("npc_us_bradley_h")
    PatchClass("npc_us_bradley_turret")
    PatchClass("npc_us_bradley_turret_h")
    PatchClass("npc_us_m24")
    PatchClass("npc_us_m24_h")
    PatchClass("npc_us_m48")
    PatchClass("npc_us_m48_h")
    PatchClass("npc_us_m48_turret")
    PatchClass("npc_us_m48_turret_h")
    PatchClass("npc_us_m60")
    PatchClass("npc_us_m60_h")
    PatchClass("npc_us_m60_turret")
    PatchClass("npc_us_m60_turret_h")
    PatchClass("npc_us_abrams")
    PatchClass("npc_us_abrams_h")
    PatchClass("npc_us_abrams_turret")
    PatchClass("npc_us_abrams_turret_h")
    PatchClass("npc_us_m103")
    PatchClass("npc_us_m103_h")
    PatchClass("npc_us_m103_turret")
    PatchClass("npc_us_m103_turret_h")
    PatchClass("npc_us_m1a2")
    PatchClass("npc_us_m1a2_h")
    PatchClass("npc_us_m1a2_turret")
    PatchClass("npc_us_m1a2_turret_h")
    PatchClass("npc_us_paladin")
    PatchClass("npc_us_paladin_h")
    PatchClass("npc_us_paladin_turret")
    PatchClass("npc_us_paladin_turret_h")
    PatchClass("npc_us_palmgtur")
    PatchClass("npc_us_palmgtur_h")
end

hook.Add("InitPostEntity", "DCityPatch_VJMilitaryGuard", InstallGuards)
timer.Create("DCityPatch_VJMilitaryGuardRetry", 2, 30, function()
    if not cvEnable:GetBool() then return end

    local a = PatchClass("npc_rf_t90mgturret")
    local b = PatchClass("npc_rf_t90mgturret_h")
    local c = PatchClass("npc_su_t54_turret")
    local d = PatchClass("npc_su_t54_turret_h")
    local e = PatchClass("npc_su_t64bv_turret")
    local f = PatchClass("npc_su_t64bv_turret_h")
    local g = PatchClass("npc_su_mg")
    local h = PatchClass("npc_su_mg_h")
    local i = PatchClass("npc_su_t72_turret")
    local j = PatchClass("npc_su_t72_turret_h")
    local k = PatchClass("npc_us_browningmg")
    local l = PatchClass("npc_us_browningmg_h")
    local m = PatchClass("npc_us_bradley")
    local n = PatchClass("npc_us_bradley_h")
    local o = PatchClass("npc_us_bradley_turret")
    local p = PatchClass("npc_us_bradley_turret_h")
    local q = PatchClass("npc_us_m24")
    local r = PatchClass("npc_us_m24_h")
    local s = PatchClass("npc_us_m48")
    local t = PatchClass("npc_us_m48_h")
    local u = PatchClass("npc_us_m48_turret")
    local v = PatchClass("npc_us_m48_turret_h")
    local w = PatchClass("npc_us_m60")
    local x = PatchClass("npc_us_m60_h")
    local y = PatchClass("npc_us_m60_turret")
    local z = PatchClass("npc_us_m60_turret_h")
    local aa = PatchClass("npc_us_abrams")
    local ab = PatchClass("npc_us_abrams_h")
    local ac = PatchClass("npc_us_abrams_turret")
    local ad = PatchClass("npc_us_abrams_turret_h")
    local ae = PatchClass("npc_us_m103")
    local af = PatchClass("npc_us_m103_h")
    local ag = PatchClass("npc_us_m103_turret")
    local ah = PatchClass("npc_us_m103_turret_h")
    local ai = PatchClass("npc_us_m1a2")
    local aj = PatchClass("npc_us_m1a2_h")
    local ak = PatchClass("npc_us_m1a2_turret")
    local al = PatchClass("npc_us_m1a2_turret_h")
    local am = PatchClass("npc_us_paladin")
    local an = PatchClass("npc_us_paladin_h")
    local ao = PatchClass("npc_us_paladin_turret")
    local ap = PatchClass("npc_us_paladin_turret_h")
    local aq = PatchClass("npc_us_palmgtur")
    local ar = PatchClass("npc_us_palmgtur_h")
    if a and b and c and d and e and f and g and h and i and j and k and l and m and n and o and p and q and r and s and t and u and v and w and x and y and z and aa and ab and ac and ad and ae and af and ag and ah and ai and aj and ak and al and am and an and ao and ap and aq and ar then
        timer.Remove("DCityPatch_VJMilitaryGuardRetry")
    end
end)