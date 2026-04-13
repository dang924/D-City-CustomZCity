-- Patch-side NULL guard for base furry class hooks.
-- Prevents "Tried to use a NULL entity" spam from sv_furry.lua without
-- editing base ZCity files.

if not SERVER then return end

local fur_pain = {
    "zbattle/furry/exp5.wav",
    "zbattle/furry/exp6.wav",
    "zbattle/furry/exp7.wav",
    "zbattle/furry/exp8.wav",
    "zbattle/furry/exp9.wav",
    "zbattle/furry/exp10.wav",
    "zbattle/furry/exp11.wav",
    "zbattle/furry/exp12.wav",
    "zbattle/furry/exp13.wav",
    "zbattle/furry/exp14.wav",
    "zbattle/furry/exp15.wav",
    "zbattle/furry/exp16.wav",
    "zbattle/furry/exp17.wav",
    "zbattle/furry/death1.wav",
    "zbattle/furry/death3.wav",
    "zbattle/furry/death4.wav",
    "zbattle/furry/death5.wav",
}

local function IsValidFurryOwner(owner, org)
    return IsValid(owner)
        and owner:IsPlayer()
        and owner:Alive()
        and owner.PlayerClassName == "furry"
        and istable(org)
end

local function InstallFurryGuards()
    -- Same hook IDs as base so these replace unsafe callbacks.
    hook.Add("Org Think", "regenerationfurry", function(owner, org, timeValue)
        if not IsValidFurryOwner(owner, org) then return end

        local dt = tonumber(timeValue) or 0
        if dt <= 0 then return end

        org.blood = math.Approach(tonumber(org.blood) or 0, 5000, dt * 60)

        if istable(org.wounds) then
            for _, wound in pairs(org.wounds) do
                if istable(wound) then
                    wound[1] = math.max((tonumber(wound[1]) or 0) - dt * 0.6, 0)
                end
            end
        end

        if istable(org.arterialwounds) then
            for _, wound in pairs(org.arterialwounds) do
                if istable(wound) then
                    wound[1] = math.max((tonumber(wound[1]) or 0) - dt * 0.6, 0)
                end
            end
        end

        org.internalBleed = math.max((tonumber(org.internalBleed) or 0) - dt * 0.6, 0)

        local regen = dt / 60

        org.lleg = math.max((tonumber(org.lleg) or 0) - regen, 0)
        org.rleg = math.max((tonumber(org.rleg) or 0) - regen, 0)
        org.rarm = math.max((tonumber(org.rarm) or 0) - regen, 0)
        org.larm = math.max((tonumber(org.larm) or 0) - regen, 0)
        org.chest = math.max((tonumber(org.chest) or 0) - regen, 0)
        org.pelvis = math.max((tonumber(org.pelvis) or 0) - regen, 0)
        org.spine1 = math.max((tonumber(org.spine1) or 0) - regen, 0)
        org.spine2 = math.max((tonumber(org.spine2) or 0) - regen, 0)
        org.spine3 = math.max((tonumber(org.spine3) or 0) - regen, 0)
        org.skull = math.max((tonumber(org.skull) or 0) - regen, 0)

        org.llegdislocation = false
        org.rlegdislocation = false
        org.rarmdislocation = false
        org.larmdislocation = false
        org.jawdislocation = false

        org.liver = math.max((tonumber(org.liver) or 0) - regen, 0)
        org.intestines = math.max((tonumber(org.intestines) or 0) - regen, 0)
        org.heart = math.max((tonumber(org.heart) or 0) - regen, 0)
        org.stomach = math.max((tonumber(org.stomach) or 0) - regen, 0)

        if istable(org.lungsR) then
            org.lungsR[1] = math.max((tonumber(org.lungsR[1]) or 0) - regen, 0)
            org.lungsR[2] = math.max((tonumber(org.lungsR[2]) or 0) - regen, 0)
        end
        if istable(org.lungsL) then
            org.lungsL[1] = math.max((tonumber(org.lungsL[1]) or 0) - regen, 0)
            org.lungsL[2] = math.max((tonumber(org.lungsL[2]) or 0) - regen, 0)
        end

        org.brain = math.max((tonumber(org.brain) or 0) - regen * 0.1, 0)
        org.hungry = 0
    end)

    hook.Add("Org Think", "ItHurtsfrfr", function(owner, org)
        if not IsValid(owner) or not owner:IsPlayer() then return end
        if owner.PlayerClassName ~= "furry" then return end
        if not istable(org) then return end

        if (owner.lastPainSoundCD or 0) < CurTime() and not org.otrub and (tonumber(org.pain) or 0) >= 30 and math.random(1, 50) == 1 then
            local phrase = fur_pain[math.random(#fur_pain)]
            local muffed = istable(owner.armors) and owner.armors["face"] == "mask2"

            owner:EmitSound(phrase, muffed and 65 or 75, owner.VoicePitch or 100, 1)
            owner.lastPainSoundCD = CurTime() + math.Rand(10, 25)
            owner.lastPhr = phrase
        end
    end)

    -- Guarded variant in case non-player/null slips through replacement hook chain.
    hook.Add("HG_ReplaceBurnPhrase", "UwUBurnPhrases", function(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if ply.PlayerClassName ~= "furry" then return end
        return ply, fur_pain[math.random(#fur_pain)]
    end)

    print("[ZC Patch] Installed furry NULL guards")
end

timer.Simple(0, InstallFurryGuards)
