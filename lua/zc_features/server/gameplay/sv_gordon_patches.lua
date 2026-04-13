-- sv_gordon_patches.lua
-- 1. Gravity gun (weapon_physcannon) works while Gordon is ragdolled (WorkWithFake)
-- 2. When Gordon loses a leg, mitigate the worst effects and broadcast a funny message
-- 3. Serverwide randomised chat message on Gordon leg loss

if CLIENT then return end

-- ── 1. Physcannon WorkWithFake ─────────────────────────────────────────────────
-- weapon_physcannon is a GMod base weapon with no homigrad_base inheritance,
-- so it lacks WorkWithFake. We set it after the weapon has been created.

local function PatchPhyscannon(wep)
    if not IsValid(wep) then return end
    if wep:GetClass() ~= "weapon_physcannon" then return end
    wep.WorkWithFake = true
end

hook.Add("OnEntityCreated", "ZC_Gordon_PhyscannonPatch", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "weapon_physcannon" then return end
    -- Defer one tick so the weapon has fully initialized
    timer.Simple(0, function()
        PatchPhyscannon(ent)
    end)
end)

-- Also patch any already-existing physcannons on map load
hook.Add("InitPostEntity", "ZC_Gordon_PhyscannonPatchExisting", function()
    for _, wep in ipairs(ents.FindByClass("weapon_physcannon")) do
        PatchPhyscannon(wep)
    end
end)

-- ── 2. Leg loss mitigations for Gordon ────────────────────────────────────────
-- When Gordon loses a leg:
--   a) HEV auto-injects morphine to suppress the worst of the pain/shock spike
--   b) Prevents the organism from immediately forcing a ragdoll (buys time to react)
--   c) Clamps shock to a survivable level so he doesn't instantly die

local LEG_LIMBS = { lleg = true, rleg = true }

local LEG_MESSAGES = {
    "Gordon Freeman has lost a leg. The HEV suit is compensating.",
    "Gordon Freeman's leg has been severed. Someone get him a wheelchair.",
    "The HEV suit reports critical leg damage on Freeman. He's still in there.",
    "Gordon Freeman is down a leg. The Lambda team requests a moment of silence.",
    "One leg down. Gordon Freeman continues to defy medical science.",
    "HEV suit: 'Morphine administered.' Gordon Freeman has lost a leg.",
    "Gordon Freeman lost a leg. Barney probably has something to say about this.",
    "Freeman's leg: gone. Freeman's will: unbroken.",
    "Well, it's not like Gordon needs BOTH legs to save the world.",
    "HEV suit critical alert: limb loss detected. Gordon Freeman remains operational.",
}

hook.Add("OnAmputateLimb", "ZC_Gordon_LegLoss", function(org, ent, limb)
    if not LEG_LIMBS[limb] then return end

    local owner = org.owner
    if not IsValid(owner) or not owner:IsPlayer() then return end
    if owner.PlayerClassName ~= "Gordon" then return end

    -- a) Clamp shock so he doesn't immediately die from the trauma spike
    --    (AmputateLimb sets shock=100 for NPCs; players get the pain cascade instead)
    timer.Simple(0.05, function()
        if not IsValid(owner) or not org.alive then return end
        org.shock = math.min(org.shock, 60)
        org.pain  = math.min(org.pain,  80)
    end)

    -- b) HEV auto-morphine: suppress pain/shock further if the suit has morphine
    if owner.HEV and owner.HEV.Morphine and owner.HEV.Morphine > 0 then
        local dose = math.min(owner.HEV.Morphine, 1.5)
        owner.HEV.Morphine = owner.HEV.Morphine - dose
        owner:SetNetVar("HEVMedicine", owner.HEV.Medicine)

        timer.Simple(0.1, function()
            if not IsValid(owner) or not org.alive then return end
            org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + dose, 4)
            org.shock = math.min(org.shock, 45)
            owner:Notify(
                "HEV suit: Emergency morphine administered. " ..
                string.format("%.0f%%", (owner.HEV.Morphine / 4) * 100) ..
                " morphine remaining.",
                true, "hev_legmorphine", 4
            )
        end)
    end

    -- c) Prevent the ragdoll-force that normally triggers immediately on leg loss
    --    by briefly setting canmove to give the player a moment to react
    --    Only if he isn't already ragdolled
    if not IsValid(owner.FakeRagdoll) then
        org.needfake = false
        timer.Simple(0.3, function()
            if not IsValid(owner) or not org.alive then return end
            -- Re-allow normal ragdoll logic after the brief grace window
            org.needfake = (org.spine1 and org.spine1 >= (hg.organism.fake_spine1 or 0.5))
        end)
    end

    -- d) Serverwide broadcast
    local msg = LEG_MESSAGES[math.random(#LEG_MESSAGES)]
    local legName = limb == "lleg" and "left" or "right"
    local full = "[HEV] " .. owner:Nick() .. " lost their " .. legName .. " leg.  " .. msg

    if zChatPrint then
        zChatPrint(Color(255, 125, 0), full)
    else
        PrintMessage(HUD_PRINTTALK, full)
    end

    print("[ZC Gordon] " .. full)
end)
