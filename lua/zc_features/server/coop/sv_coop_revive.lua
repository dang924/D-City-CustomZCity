-- provided the target has no amputated limbs.
-- Uses the same eyetrace pattern as ZCity's hg_fixdislocation concommand.

local initialized = false
local function Initialize()
    if initialized then return end
    initialized = true
    local REVIVE_RANGE   = 100  -- units, how close the reviver must be
    local REVIVE_COOLDOWN = 8   -- seconds between revive attempts per player

    local REVIVER_CLASSES = {
        ["Gordon"] = true,
    }

    local function IsReviver(ply)
        if REVIVER_CLASSES[ply.PlayerClassName] then return true end
        if ply.subClass == "medic" then return true end
        return false
    end

    local function HasAmputatedLeg(org)
        -- Only block revive if legs are missing (back-carry only for leg amputees)
        -- Arm/head amputees can still be revived
        return org.llegamputated or org.rlegamputated
    end

    local function BackCarryWillHandle(reviver, target)
        return isfunction(ZC_BackCarryWouldHandle) and ZC_BackCarryWouldHandle(reviver, target) or false
    end

    local function RevivePlayer(reviver, target)
        if not IsValid(reviver) or not IsValid(target) then return end
        if not reviver:Alive() or not target:Alive() then return end
        if not IsReviver(reviver) then return end
        if not reviver.organism or reviver.organism.otrub then return end

        local org = target.organism
        if not org then return end
        if not org.otrub then
            reviver:ChatPrint("[ZCity] " .. target:Nick() .. " is not incapacitated.")
            return
        end

        -- Block if legs are amputated (back-carry only system for leg amputees)
        if HasAmputatedLeg(org) then
            reviver:ChatPrint("[ZCity] Cannot revive " .. target:Nick() .. " — missing leg(s). Use Back Carry instead.")
            target:ChatPrint("[ZCity] " .. reviver:Nick() .. " cannot revive you — you are missing leg(s). Use Back Carry.")
            return
        end

        -- Cooldown check
        if (reviver.ZCReviveCooldown or 0) > CurTime() then
            local remaining = math.ceil(reviver.ZCReviveCooldown - CurTime())
            reviver:ChatPrint("[ZCity] Revive on cooldown for " .. remaining .. "s.")
            return
        end
        reviver.ZCReviveCooldown = CurTime() + REVIVE_COOLDOWN

        -- Reset the organism values that keep needotrub = true.
        -- Mirrors the thresholds checked in sv_organism.lua line ~100:
        -- otrub fires when: blood < 2900, consciousness <= 0.4, spine damage,
        -- both legs broken, or otrub already set.
        org.blood        = math.max(org.blood, 3200)   -- above the 2900 faint threshold
        org.consciousness = 1
        org.spine1       = 0
        org.spine2       = 0
        org.spine3       = 0
        org.lleg         = 0
        org.rleg         = 0
        org.pain         = math.min(org.pain, 20)       -- reduce but don't zero (still hurt)
        org.shock        = math.min(org.shock, 10)
        org.pulse        = math.max(org.pulse, 40)      -- enough to sustain
        org.heartstop    = false
        org.needotrub    = false
        org.otrub        = false
        org.uncon_timer  = 0

        -- Seal any open wounds partially so they don't immediately re-down the player
        if org.wounds then
            for _, wound in pairs(org.wounds) do
                wound[1] = math.min(wound[1], 0.3)
            end
        end

        -- Use ZCity's FakeUp to physically stand the player up
        hg.FakeUp(target, true)

        -- Notify both parties
        reviver:ChatPrint("[ZCity] You revived " .. target:Nick() .. ".")
        target:ChatPrint("[ZCity] You were revived by " .. reviver:Nick() .. ".")
        target:EmitSound("hl1/fvox/bell.wav", 70)

        -- Cancel bleed-out timer if our bleedout addon is loaded
        local bleedoutTimer = "ZC_BleedOut_" .. target:SteamID64()
        if timer.Exists(bleedoutTimer) then
            timer.Remove(bleedoutTimer)
        end
    end

    hook.Add("KeyPress", "ZCity_Revive", function(ply, key)
        if key ~= IN_USE then return end
        if not IsValid(ply) or not ply:Alive() then return end
        if not IsReviver(ply) then return end
        if ply.organism and ply.organism.otrub then return end

        local tr = hg.eyeTrace(ply)
        local target = tr.Entity

        -- Accept both the player entity and their fake ragdoll
        if IsValid(target) and not target:IsPlayer() and target.ply then
            target = target.ply
        end

        if not IsValid(target) or not target:IsPlayer() then return end
        if target == ply then return end
        if not target.organism or not target.organism.otrub then return end
        if target:GetPos():Distance(ply:GetPos()) > REVIVE_RANGE then return end
        if BackCarryWillHandle(ply, target) then return end

        RevivePlayer(ply, target)
    end)
end

local function IsCoopRoundActive()
    if not CurrentRound then return false end

    local round = CurrentRound()
    return istable(round) and round.name == "coop"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svcooprevive", function()
    if not IsCoopRoundActive() then return end
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svcooprevive_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svcooprevive_Late")
        return
    end
    if not IsCoopRoundActive() then return end
    Initialize()
end)
