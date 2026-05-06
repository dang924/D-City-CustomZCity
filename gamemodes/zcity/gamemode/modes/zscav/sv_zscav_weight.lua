-- ZScav weight, stamina, and encumbrance movement pipeline.

ZSCAV = ZSCAV or {}

ZSCAV.WeightRagdollCheckInterval = ZSCAV.WeightRagdollCheckInterval or 0.35
ZSCAV.WeightRagdollCooldown = ZSCAV.WeightRagdollCooldown or 1.5
ZSCAV.WeightCrouchToggleStaminaCost = ZSCAV.WeightCrouchToggleStaminaCost or 1.5
ZSCAV.WeightRagdollToggleStaminaCost = ZSCAV.WeightRagdollToggleStaminaCost or 3.0

local function ResetWeightState(ply)
    if not IsValid(ply) then return end

    ply.StaminaExhaustMul = 1
    ply.zscav_disable_stamina_move_debuff = false
    ply.zscav_weight_total_kg = 0
    ply.zscav_weight_move_mul = 1
    ply.zscav_weight_walk_mul = 1
    ply.zscav_weight_sprint_mul = 1
    ply.zscav_weight_speed_gain_mul = 1
    ply.zscav_weight_inertia_mul = 1
    ply.zscav_weight_profile_id = "light"
    ply.zscav_weight_block_sprint = false
    ply.zscav_weight_sprint_attempt_ragdoll = false
    ply.zscav_weight_move_ragdoll_chance = 0
    ply.zscav_weight_sprint_ragdoll_chance = 0
    ply.zscav_weight_sprint_attempting = false
    ply.zscav_weight_ragdoll_cooldown_until = 0
    ply.zscav_weight_next_random_ragdoll_check = 0
    ply.zscav_weight_force_stamina_drain_until = 0
    ply.zscav_weight_stamina_sprint_blocked = false
    ply.zscav_weight_prev_crouching = ply:Crouching()
end

function ZSCAV:ResetWeightState(ply)
    ResetWeightState(ply)
end

local function SetSprintDrainBridge(ply, sprintAttempt)
    if not IsValid(ply) then return end

    if sprintAttempt then
        ply.zscav_weight_force_stamina_drain_until = CurTime() + 0.15
    else
        ply.zscav_weight_force_stamina_drain_until = 0
    end
end

local function IsSprintAttempt(cmd)
    if not (cmd and cmd.KeyDown and cmd.GetForwardMove) then return false end
    return cmd:KeyDown(IN_SPEED)
        and not cmd:KeyDown(IN_DUCK)
        and (cmd:KeyDown(IN_FORWARD) or (tonumber(cmd:GetForwardMove()) or 0) > 0)
end

local function GetStaminaFrac(ply)
    local org = IsValid(ply) and ply.organism or nil
    local stamina = org and org.stamina or nil
    local maxValue = tonumber(stamina and (stamina.max or stamina.range)) or 180
    if maxValue <= 0 then return 1 end

    local curValue = math.Clamp(tonumber(stamina and stamina[1]) or maxValue, 0, maxValue)
    return curValue / maxValue
end

local function GetBlockedSprintMul(ply, walkMul)
    local runSpeed = math.max(tonumber(IsValid(ply) and ply:GetRunSpeed()) or 1, 1)
    local walkSpeed = math.max(tonumber(IsValid(ply) and ply:GetWalkSpeed()) or 1, 1)
    return math.max((walkSpeed * math.max(walkMul or 1, 0.01)) / runSpeed, 0.01)
end

local function ApplyStaminaCost(ply, amount)
    if not (IsValid(ply) and ply:Alive()) then return end

    local org = ply.organism
    local stamina = org and org.stamina or nil
    amount = math.max(tonumber(amount) or 0, 0)
    if not (istable(stamina) and amount > 0) then return end

    local maxValue = math.max(tonumber(stamina.max or stamina.range) or tonumber(stamina[1]) or 0, 1)
    stamina[1] = math.Clamp((tonumber(stamina[1]) or maxValue) - amount, 0, maxValue)
end

local function GetSprintStaminaMul(ply, walkMul, sprintMul)
    local softStart = math.Clamp(tonumber(ZSCAV.WeightSprintStaminaSoftStartFrac) or 0.20, 0.05, 0.95)
    local hardBlock = math.Clamp(tonumber(ZSCAV.WeightSprintStaminaHardBlockFrac) or 0.07, 0.01, softStart - 0.01)
    local recover = math.Clamp(tonumber(ZSCAV.WeightSprintStaminaRecoverFrac) or 0.18, hardBlock + 0.01, 0.95)
    local staminaFrac = GetStaminaFrac(ply)
    local blockedMul = GetBlockedSprintMul(ply, walkMul)
    local blocked = ply.zscav_weight_stamina_sprint_blocked and true or false

    if blocked then
        if staminaFrac >= recover then
            blocked = false
        end
    elseif staminaFrac <= hardBlock then
        blocked = true
    end

    ply.zscav_weight_stamina_sprint_blocked = blocked

    if blocked then
        return blockedMul, true, staminaFrac
    end

    local baseSprintMul = math.max(tonumber(sprintMul) or walkMul or 1, 0.01)
    if staminaFrac >= softStart then
        return baseSprintMul, false, staminaFrac
    end

    local t = math.Clamp((staminaFrac - hardBlock) / (softStart - hardBlock), 0, 1)
    return Lerp(t, blockedMul, baseSprintMul), false, staminaFrac
end

local function TryWeightRagdoll(ply, force, chance)
    if not (IsValid(ply) and ply:Alive()) then return false end
    if IsValid(ply.FakeRagdoll) then return false end
    if ply:InVehicle() then return false end
    if (ply.zscav_weight_ragdoll_cooldown_until or 0) > CurTime() then return false end
    if not (hg and isfunction(hg.Fake)) then return false end

    if not force then
        chance = math.max(tonumber(chance) or 0, 0)
        if chance <= 0 or math.Rand(0, 1) > chance then return false end
    end

    hg.Fake(ply)
    if not IsValid(ply.FakeRagdoll) then return false end

    local cooldown = math.max(tonumber(ZSCAV.WeightRagdollCooldown) or 1.5, 0.1)
    local checkInterval = math.max(tonumber(ZSCAV.WeightRagdollCheckInterval) or 0.35, 0.1)
    ply.zscav_weight_ragdoll_cooldown_until = CurTime() + cooldown
    ply.zscav_weight_next_random_ragdoll_check = CurTime() + checkInterval
    return true
end

function ZSCAV:ApplyWeightToOrganism(ply)
    if not IsValid(ply) then return end
    local inv = self:GetInventory(ply)
    if not inv then
        ResetWeightState(ply)
        return
    end

    local weight = tonumber(self.GetTotalWeight and self:GetTotalWeight(inv) or self:GetGridCarryWeight(inv)) or 0
    local profile = self.GetWeightMovementProfile and self:GetWeightMovementProfile(weight) or nil
    if not istable(profile) then
        ResetWeightState(ply)
        return
    end

    ply.zscav_weight_total_kg = weight
    ply.zscav_disable_stamina_move_debuff = true
    ply.zscav_weight_move_mul = tonumber(profile.walkMul) or 1
    ply.zscav_weight_walk_mul = tonumber(profile.walkMul) or 1
    ply.zscav_weight_sprint_mul = tonumber(profile.sprintMul) or 1
    ply.zscav_weight_speed_gain_mul = tonumber(profile.speedGainMul) or 1
    ply.zscav_weight_inertia_mul = tonumber(profile.inertiaMul) or 1
    ply.zscav_weight_profile_id = tostring(profile.id or "light")
    ply.zscav_weight_block_sprint = profile.blockSprint and true or false
    ply.zscav_weight_sprint_attempt_ragdoll = profile.sprintAttemptRagdoll and true or false
    ply.zscav_weight_move_ragdoll_chance = tonumber(profile.moveRagdollChance) or 0
    ply.zscav_weight_sprint_ragdoll_chance = tonumber(profile.sprintRagdollChance) or 0
    ply.StaminaExhaustMul = math.max(tonumber(profile.staminaMul) or 1, 1)
end

hook.Add("HG_MovementCalc", "ZSCAV_WeightAcceleration", function(_vel, _velLen, _weightmul, ply, _cmd, _mv)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not ply:Alive() then return end

    local walkMul = tonumber(ply.zscav_weight_walk_mul)
    if not walkMul then
        ZSCAV:ApplyWeightToOrganism(ply)
        walkMul = tonumber(ply.zscav_weight_walk_mul) or 1.0
    end

    if walkMul >= 1.0 then return end

    local speedGainMul = math.max(tonumber(ply.zscav_weight_speed_gain_mul) or walkMul, 0.05)
    local inertiaMul = math.max(tonumber(ply.zscav_weight_inertia_mul) or walkMul, 0.05)

    ply.SpeedGainMul = math.max((tonumber(ply.SpeedGainMul) or 240) * speedGainMul, 1)
    ply.InertiaBlend = math.max((tonumber(ply.InertiaBlend) or 2000) * inertiaMul, 1)
end)

hook.Add("HG_MovementCalc_2", "ZSCAV_WeightMobility", function(mul, ply, cmd, _mv)
    if not ZSCAV:IsActive() then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if not istable(mul) then return end

    local walkMul = tonumber(ply.zscav_weight_walk_mul)
    if not walkMul then
        ZSCAV:ApplyWeightToOrganism(ply)
        walkMul = tonumber(ply.zscav_weight_walk_mul) or 1.0
    end

    local sprintAttempt = IsSprintAttempt(cmd)

    if sprintAttempt and not ply.zscav_weight_sprint_attempting then
        ply.zscav_weight_sprint_attempting = true

        if ply.zscav_weight_sprint_attempt_ragdoll then
            if cmd and cmd.RemoveKey then cmd:RemoveKey(IN_SPEED) end
            if _mv and _mv.RemoveKey then _mv:RemoveKey(IN_SPEED) end

            if TryWeightRagdoll(ply, true) then
                mul[1] = 0.01
                return
            end
        end
    elseif not sprintAttempt then
        ply.zscav_weight_sprint_attempting = false
    end

    local effectiveMul = walkMul
    local sprintingActive = false
    if sprintAttempt then
        if ply.zscav_weight_block_sprint then
            if cmd and cmd.RemoveKey then cmd:RemoveKey(IN_SPEED) end
            if _mv and _mv.RemoveKey then _mv:RemoveKey(IN_SPEED) end
            effectiveMul = GetBlockedSprintMul(ply, walkMul)
        else
            local staminaMul, staminaBlocked = GetSprintStaminaMul(
                ply,
                walkMul,
                tonumber(ply.zscav_weight_sprint_mul) or walkMul
            )

            effectiveMul = math.max(staminaMul or walkMul, 0.01)
            if staminaBlocked then
                if cmd and cmd.RemoveKey then cmd:RemoveKey(IN_SPEED) end
                if _mv and _mv.RemoveKey then _mv:RemoveKey(IN_SPEED) end
            else
                sprintingActive = true
            end
        end
    else
        ply.zscav_weight_stamina_sprint_blocked = false
    end

    SetSprintDrainBridge(ply, sprintingActive)

    local now = CurTime()
    local ragdollChance = sprintingActive and (tonumber(ply.zscav_weight_sprint_ragdoll_chance) or 0)
        or (tonumber(ply.zscav_weight_move_ragdoll_chance) or 0)

    if ragdollChance > 0 and not IsValid(ply.FakeRagdoll) then
        local nextCheck = tonumber(ply.zscav_weight_next_random_ragdoll_check) or 0
        if now >= nextCheck then
            ply.zscav_weight_next_random_ragdoll_check = now + math.max(tonumber(ZSCAV.WeightRagdollCheckInterval) or 0.35, 0.1)

            local staminaFrac = GetStaminaFrac(ply)
            local collapseMul = Lerp(1 - staminaFrac, 1.0, 1.4)
            local movingFastEnough = ply:GetVelocity():Length2D() >= (sprintingActive and 90 or 45)
            if movingFastEnough and TryWeightRagdoll(ply, false, ragdollChance * collapseMul) then
                mul[1] = 0.01
                return
            end
        end
    end

    mul[1] = math.max((tonumber(mul[1]) or 1.0) * effectiveMul, 0.01)
end)

hook.Add("Fake Up", "ZSCAV_PreserveInventoryOnFakeUp", function(ply)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end
    ApplyStaminaCost(ply, ZSCAV.WeightRagdollToggleStaminaCost)
    ply.zscav_preserve_inventory_spawn_until = CurTime() + 2
end)

hook.Add("Fake", "ZSCAV_StanceStaminaCostFake", function(ply, _ragdoll)
    if not (IsValid(ply) and ZSCAV:IsActive()) then return end
    ApplyStaminaCost(ply, ZSCAV.WeightRagdollToggleStaminaCost)
end)

hook.Add("PlayerTick", "ZSCAV_StanceStaminaCostCrouch", function(ply, _mv)
    if not (IsValid(ply) and ply:Alive() and ZSCAV:IsActive()) then return end

    local crouching = ply:Crouching()
    local previous = ply.zscav_weight_prev_crouching
    if previous == nil then
        ply.zscav_weight_prev_crouching = crouching
        return
    end

    if previous ~= crouching then
        ply.zscav_weight_prev_crouching = crouching
        ApplyStaminaCost(ply, ZSCAV.WeightCrouchToggleStaminaCost)
    end
end)