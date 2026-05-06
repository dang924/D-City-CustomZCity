-- ZScav meds: server handler for the ZScav health-tab + hotbar medical
-- actions (testing-branch native).
--
-- Wires up two hooks fired from gamemodes/zcity/gamemode/modes/zscav/sv_zscav.lua:
--
--   ZSCAV_UseMedicalTarget    (ply, inv, target, profile, args)
--     Fired by Actions.use_medical_target — drag-drop in the Health tab.
--     target = { part = partDef, grid = "pocket"|"vest"|...,
--                index = N, entry = inv_entry }
--
--   ZSCAV_UseMedicalQuickslot (ply, inv, target)
--     Fired by ActivateQuickslotBinding — hotkey press on a bound med.
--     target = { entry = inv_entry, grid = "pocket"|"vest", index = N }
--     The handler picks an appropriate body part itself.
--
-- We read ZSCAV:GetMedicalEFTData(entry.class) for the canonical pool/use/
-- treats values, mutate the player's organism + wounds tables to apply the
-- heal, then drain the pool/use counter on the inventory entry. When the
-- entry is exhausted we remove it from the grid and call SyncInventory.

if not SERVER then return end

ZScavMeds = ZScavMeds or {}

local SURGERY_DURATION = 15
local SURGERY_MOVE_CANCEL_DIST_SQR = 12 * 12
local SURGERY_SWITCH_LOCK_DURATION = 2
local SURGERY_PROGRESS_BARK_OFFSETS = { 4, 9, 13 }
local SURGERY_PROGRESS_LINES = {
    generic = {
        "Shit, that's a lot of blood..",
        "Ow, that stings.",
        "Holy fuck that hurts..",
        "Keep it together..",
        "Easy... easy...",
        "Just gotta stay steady..",
        "Come on, focus..",
        "Don't pass out on me now..",
        "This is gonna leave a mark..",
        "Breathe. Just breathe.",
        "Almost got it..",
        "Hands steady... hands steady...",
    },
    arm = {
        "Need this arm working again..",
        "Come on, fingers, wake up..",
        "If I screw this up, I lose the hand..",
        "Stay still, arm..",
        "Need this hand back online..",
    },
    left_arm = {
        "Left arm's a mess..",
        "Come on, left hand, don't quit on me..",
        "Left side's opening back up..",
        "Need that left grip back..",
    },
    right_arm = {
        "Right arm, behave..",
        "Need my trigger hand back..",
        "Come on, right hand, move for me..",
        "Don't fail me, right side..",
    },
    leg = {
        "Need this leg under me again..",
        "If this slips, I'm crawling..",
        "Stay straight, damn it..",
        "Need to walk after this..",
        "Come on, hold together..",
    },
    left_leg = {
        "Left leg's shredded..",
        "Come on, left leg, I need you..",
        "Left side's twitching like hell..",
        "Need that left leg to carry me..",
    },
    right_leg = {
        "Right leg's not done yet..",
        "Come on, right leg, hold..",
        "Need this leg for the next sprint..",
        "Right side's fighting me hard..",
    },
    thorax = {
        "Easy... too close to the ribs..",
        "Chest is a fucking disaster..",
        "Don't nick anything important..",
        "Keep breathing. Slow.",
        "One bad cut and that's it..",
    },
    stomach = {
        "God, my gut is a mess..",
        "Don't look at it. Just fix it..",
        "That pull in my stomach is awful..",
        "Keep pressure on it..",
        "Feels like my guts are in knots..",
    },
    head = {
        "Bad idea working this close to my head..",
        "Just don't black out..",
        "Easy... skull's right there..",
        "Come on, stay conscious..",
    },
}
local SURGERY_CANCEL_LINES = {
    generic = {
        "Fuck, now what?",
        "Shit, not now..",
        "I fucked up.",
        "God damn it, start over.",
        "Lost it. Lost it..",
        "Great, ruined the stitch..",
        "There goes all that work..",
        "Son of a bitch..",
    },
    arm = {
        "Perfect. There goes the hand..",
        "Arm slipped. Great.",
        "That's the arm opened up again..",
        "There goes my grip..",
    },
    left_arm = {
        "Left arm's blown open again..",
        "There goes the left hand..",
        "Left side slipped out of place..",
    },
    right_arm = {
        "There goes my good trigger hand..",
        "Right arm shifted. Fuck.",
        "Right hand's back to useless..",
    },
    leg = {
        "Great, now I'm back to limping..",
        "Knew the leg would shift..",
        "Leg moved. Start over..",
        "There goes my footing..",
    },
    left_leg = {
        "Left leg folded on me..",
        "There goes the left side again..",
        "Left leg slipped. Perfect.",
    },
    right_leg = {
        "Right leg kicked loose. Great.",
        "There goes the right side..",
        "Right leg moved. Fuck.",
    },
    thorax = {
        "Chest shifted. Bad, bad, bad..",
        "Nope. Not re-opening my chest like that..",
        "That chest stitch is gone..",
    },
    stomach = {
        "Gut opened back up. Fantastic.",
        "There goes my stomach stitch..",
        "Nope. Belly slipped again..",
    },
    head = {
        "Nope. Not doing head work like that..",
        "Head moved. Absolutely not..",
        "Yeah, that's a restart..",
    },
}
local SURGERY_PATIENT_PROGRESS_LINES = {
    generic = {
        "Hold still... almost there..",
        "Need to keep this clean and closed..",
        "That's a lot of blood. Keep pressure on it..",
        "Come on, stay with me..",
        "Just need this stitch to hold..",
        "Easy... don't let them tear it back open..",
    },
    arm = {
        "Need this arm working again for them..",
        "Hand's torn up bad. Keep it steady..",
        "Come on, just give me one clean pass on this arm..",
    },
    left_arm = {
        "Left arm's a mess. Need that hand back..",
        "Come on, left arm, hold together..",
    },
    right_arm = {
        "Right arm's chewed up bad..",
        "Need their right hand back online..",
    },
    leg = {
        "Need this leg carrying them again..",
        "Keep the joint lined up..",
        "Just need this leg to hold weight again..",
    },
    left_leg = {
        "Left leg's opened up bad..",
        "Come on, left side, hold together..",
    },
    right_leg = {
        "Right leg's in rough shape..",
        "Need that right side supporting them again..",
    },
    thorax = {
        "Easy... too close to their ribs..",
        "Need to keep their chest sealed..",
        "One bad cut and this gets much worse..",
    },
    stomach = {
        "Their gut's a mess..",
        "Keep the abdomen closed. Don't rush it..",
        "Just hold still and let me finish this stomach stitch..",
    },
    head = {
        "Working this close to their head is a bad time..",
        "Easy... just keep them with me..",
    },
}
local SURGERY_PATIENT_CANCEL_LINES = {
    generic = {
        "They moved. Start over..",
        "Lost the stitch. Damn it..",
        "Can't close it like that..",
        "There goes the field. Start again..",
        "Not clean anymore. Fuck..",
    },
    arm = {
        "Arm slipped. There goes that stitch..",
        "That hand jerked loose. Great..",
    },
    left_arm = {
        "Left arm shifted. Start over..",
        "There goes the left-side stitch..",
    },
    right_arm = {
        "Right arm moved. Damn it..",
        "Lost the right-hand stitch..",
    },
    leg = {
        "Leg kicked loose. Start over..",
        "There goes the leg stitch..",
    },
    left_leg = {
        "Left leg shifted. Perfect..",
        "Lost the left-leg stitch..",
    },
    right_leg = {
        "Right leg moved. Damn it..",
        "There goes the right-leg stitch..",
    },
    thorax = {
        "Chest shifted. Can't finish it like that..",
        "Lost the chest stitch. Start over..",
    },
    stomach = {
        "Abdomen slipped open again..",
        "There goes the stomach stitch..",
    },
    head = {
        "Head moved. Not doing that blind..",
        "Lost the line on their head. Restart..",
    },
}
local SURGERY_PARALYZED_LINES = {
    generic = {
        "Why won't anything move..",
        "No... move, damn you..",
        "I'm here, but my body's not listening..",
        "Everything feels numb and wrong..",
        "Head's spinning... I can't do this..",
        "Need to move first. Need to breathe.",
        "Can't brace for this. Not like this..",
        "My body's just not answering me..",
        "I can't tell what anything below me is doing..",
        "Something in me is unplugged..",
    },
    arm = {
        "Hands won't steady. Not like this..",
        "Need my hands and they're just dead weight..",
        "Arms aren't listening to me..",
    },
    leg = {
        "Can't even plant my legs for this..",
        "No feeling under me. I can't do this..",
        "If I try this now, I'm just going to fold..",
    },
    left_arm = {
        "Left arm won't hold still... or hold at all..",
        "Can't trust my left hand with this..",
    },
    right_arm = {
        "Right hand won't obey me..",
        "Can't work with my right arm like this..",
    },
    left_leg = {
        "Can't feel my left leg enough to brace..",
        "Left side's just gone under me..",
    },
    right_leg = {
        "Right leg's dead under me..",
        "Can't anchor on my right side at all..",
    },
    thorax = {
        "Can't even get a proper breath for this..",
        "Chest is too tight and everything's swimming..",
    },
    stomach = {
        "I'm too twisted up inside to do this right..",
        "Gut feels wrong and I can't even steady myself..",
    },
    head = {
        "Can't think straight enough for this..",
        "Vision's swimming too hard. No..",
    },
    spine2 = {
        "I can't feel anything below my torso..",
        "Lower half's just gone..",
        "Back's ruined. Not like this..",
    },
    spine3 = {
        "Can't move. Can't breathe right. Fuck..",
        "Neck won't let me do a damn thing..",
        "Can't even force the words out..",
    },
    incapacitated = {
        "Too dizzy... can't do this..",
        "Need a second... everything's spinning..",
        "Body keeps trying to drop out on me..",
    },
    canmove = {
        "I keep telling myself to move and nothing happens..",
        "My body's just not taking orders..",
    },
}
local SURGERY_SUCCESS_GAG_LINE = "Wait.. is that backwards?"
local TREATMENT_RECOVERY_DURATION = 12
local TREATMENT_RECOVERY_BLOOD_RATE = 900
local TREATMENT_RECOVERY_OXYGEN_RATE = 18
local TREATMENT_RECOVERY_PAIN_THRESHOLD = 60
local TREATMENT_RECOVERY_INTERNAL_BLEED_MAX = 0.05
local SURGERY_THORAX_INTERNAL_BLEED_MIN = 0.15
local SURGERY_THORAX_PNEUMOTHORAX_MIN = 0.05
local SURGERY_THORAX_TRACHEA_MIN = 0.15
local SURGERY_THORAX_LUNG_TISSUE_MIN = 0.15
local SURGERY_THORAX_LUNG_COLLAPSE_MIN = 0.15
local SURGERY_HEAD_BRAIN_MIN = 0.08
local SURGERY_HEAD_SKULL_MIN = 0.6
local pendingSurgery = {}

-- ---------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------

-- Map a body-part ID to the organism fields whose damage feeds that part's
-- HP in cl_zscav.lua's ZSCAV_GetHealthPartStructuralDamageCL. Part HP is
-- max_hp * (1 - max(damage_organ_X, damage_organ_Y, ...)), so reducing
-- every listed organ by `damageFracHealed` and clamping at 0 cleanly heals
-- the part regardless of which organ was the dominant damage source.
local PART_TO_ORGANS = {
    head      = { "skull", "brain" },
    thorax    = { "chest", "heart", "trachea", "lungsL", "lungsR" },
    stomach   = { "stomach", "liver", "intestines", "pelvis" },
    left_arm  = { "larm" },
    right_arm = { "rarm" },
    left_leg  = { "lleg" },
    right_leg = { "rleg" },
}

local PART_TO_AMPUTATION = {
    left_arm  = "larm",
    right_arm = "rarm",
    left_leg  = "lleg",
    right_leg = "rleg",
}

local function getOrganism(ply)
    if not IsValid(ply) then return nil end
    return istable(ply.organism) and ply.organism or nil
end

local function appendStringList(out, list)
    if not istable(out) or not istable(list) then return out end

    for index = 1, #list do
        local line = string.Trim(tostring(list[index] or ""))
        if line ~= "" then
            out[#out + 1] = line
        end
    end

    return out
end

local function copyStringList(list)
    local out = {}
    appendStringList(out, list)
    return out
end

local function getSurgeryLinePool(source, partID, extraKeys)
    local out = {}
    if not istable(source) then return out end

    appendStringList(out, source.generic or source)

    if istable(extraKeys) then
        for _, key in ipairs(extraKeys) do
            appendStringList(out, source[tostring(key or "")])
        end
    end

    if partID == "left_arm" or partID == "right_arm" then
        appendStringList(out, source.arm)
    elseif partID == "left_leg" or partID == "right_leg" then
        appendStringList(out, source.leg)
    end

    appendStringList(out, source[tostring(partID or "")])

    return out
end

local function pickRandomLine(list)
    if not istable(list) or #list == 0 then return nil end
    return tostring(list[math.random(1, #list)] or "")
end

local function popRandomLine(list)
    if not istable(list) or #list == 0 then return nil end

    local index = math.random(1, #list)
    local line = tostring(list[index] or "")
    table.remove(list, index)

    if line == "" then return nil end
    return line
end

local function noticePlayer(ply, msg, msgKey, cooldown, clr)
    if not IsValid(ply) then return end

    msg = string.Trim(tostring(msg or ""))
    if msg == "" then return end

    if isfunction(ply.Notify) then
        return ply:Notify(msg, cooldown or 0.75, msgKey, 0, nil, clr)
    end

    local helpers = ZSCAV and ZSCAV.ServerHelpers
    if helpers and isfunction(helpers.Notice) then
        helpers.Notice(ply, msg)
        return
    end

    ply:ChatPrint(msg)
end

local function SurgeryProgressStart(ply, duration, class, partLabel)
    if not IsValid(ply) then return end

    net.Start("ZScavSurgeryProgress")
        net.WriteBool(true)
        net.WriteFloat(CurTime() + math.max(duration or SURGERY_DURATION, 0))
        net.WriteFloat(math.max(duration or SURGERY_DURATION, 0))
        net.WriteString(tostring(class or ""))
        net.WriteString(tostring(partLabel or ""))
    net.Send(ply)
end

local function SurgeryProgressStop(ply)
    if not IsValid(ply) then return end

    net.Start("ZScavSurgeryProgress")
        net.WriteBool(false)
        net.WriteFloat(0)
        net.WriteFloat(0)
        net.WriteString("")
        net.WriteString("")
    net.Send(ply)
end

local function armIsUsable(org, prefix)
    if not istable(org) then return true end
    if org[prefix .. "amputated"] then return false end
    return (tonumber(org[prefix]) or 0) < 1
end

local function playerHasOneUsableArm(ply)
    local org = getOrganism(ply)
    if not org then return false end

    local leftUsable = armIsUsable(org, "larm")
    local rightUsable = armIsUsable(org, "rarm")
    return leftUsable ~= rightUsable
end

local function getHandsRequiredLine(ply)
    if playerHasOneUsableArm(ply) then
        return "Gonna need my good hand.."
    end

    return "I have to put this away.."
end

local function getFakeSpineThresholds()
    local fakeSpine2 = (hg and hg.organism and tonumber(hg.organism.fake_spine2)) or 1
    local fakeSpine3 = (hg and hg.organism and tonumber(hg.organism.fake_spine3)) or 0.5
    return fakeSpine2, fakeSpine3
end

local function getSurgeryParalysisState(ply)
    local org = getOrganism(ply)
    if not org or org.otrub then return nil end

    local fakeSpine2, fakeSpine3 = getFakeSpineThresholds()

    if (tonumber(org.spine3) or 0) >= fakeSpine3 then
        return "spine3"
    end

    if (tonumber(org.spine2) or 0) >= fakeSpine2 then
        return "spine2"
    end

    if org.canmove == false then
        return "canmove"
    end

    if org.incapacitated then
        return "incapacitated"
    end

    return nil
end

local function getParalyzedSurgerySilentChance(state)
    if state == "spine3" then return 0.45 end
    if state == "spine2" then return 0.35 end
    if state == "incapacitated" then return 0.25 end
    return 0.2
end

local function getParalyzedSurgeryLine(ply, partID, state)
    if not state then return nil end
    if math.random() < getParalyzedSurgerySilentChance(state) then return nil end

    local pool = getSurgeryLinePool(SURGERY_PARALYZED_LINES, partID, { state })
    return pickRandomLine(pool)
end

local function getSurgeryNarrationSource(surgeon, patient, selfSource, patientSource)
    if IsValid(patient) and patient ~= surgeon and istable(patientSource) then
        return patientSource
    end

    return selfSource
end

local function canUseTreatmentRecovery(org)
    if not istable(org) then return false end
    if (tonumber(org.pain) or 0) > TREATMENT_RECOVERY_PAIN_THRESHOLD then return false end
    if istable(org.wounds) and #org.wounds > 0 then return false end
    if istable(org.arterialwounds) and #org.arterialwounds > 0 then return false end
    if (tonumber(org.internalBleed) or 0) > TREATMENT_RECOVERY_INTERNAL_BLEED_MAX then return false end
    return true
end

local function getTreatmentRecoveryOxygenCap(org)
    if not (istable(org) and istable(org.o2)) then return 0 end

    local o2Range = tonumber(org.o2.range) or 30
    local pneumothorax = tonumber(org.pneumothorax) or 0
    local leftLung = istable(org.lungsL) and (tonumber(org.lungsL[1]) or 0) or 0
    local rightLung = istable(org.lungsR) and (tonumber(org.lungsR[1]) or 0) or 0
    local lungIntegrity = math.max(1 - ((leftLung + rightLung) / 2), 0.5)

    return o2Range
        * math.max(1 - pneumothorax * pneumothorax, 0.1)
        * math.min((tonumber(org.blood) or 0) / 4500, 1)
        * lungIntegrity
end

local function queueTreatmentRecovery(ply)
    local org = getOrganism(ply)
    if not org then return false end

    if not canUseTreatmentRecovery(org) then
        org.zscav_treatment_recovery_until = nil
        return false
    end

    org.zscav_treatment_recovery_until = math.max(
        tonumber(org.zscav_treatment_recovery_until) or 0,
        CurTime() + TREATMENT_RECOVERY_DURATION)

    return true
end

local function getContusionReliefNeed(ply)
    local org = getOrganism(ply)
    if not org then return 0 end

    return math.max((tonumber(org.shock) or 0) - 10, 0)
        + math.max((tonumber(org.immobilization) or 0) - 1, 0) * 2
        + math.max((tonumber(org.painadd) or 0) - 8, 0) * 0.5
        + math.max((tonumber(org.disorientation) or 0) - 0.5, 0) * 12
end

local function getPainReliefNeed(ply)
    local org = getOrganism(ply)
    if not org then return 0 end

    local analgesia = tonumber(org.analgesia) or 0
    local pendingAnalgesia = tonumber(org.analgesiaAdd) or 0
    local reliefHeadroom = math.max(1 - math.min(analgesia + pendingAnalgesia * 0.25, 1), 0)

    return reliefHeadroom * (
        math.max((tonumber(org.pain) or 0) - 30, 0)
        + math.max((tonumber(org.avgpain) or 0) - 25, 0) * 0.5
        + math.max((tonumber(org.painadd) or 0) - 10, 0) * 0.6
        + math.max((tonumber(org.shock) or 0) - 15, 0) * 0.4)
end

local function getPainReliefSettings(row)
    local reliefAdd = math.max(tonumber(istable(row) and row.pain_relief_add) or 0.45, 0)
    local reliefFloor = math.max(tonumber(istable(row) and row.pain_relief_floor) or 0.2, 0)
    local reliefCap = tonumber(istable(row) and row.pain_relief_cap) or 4

    reliefCap = math.min(math.max(reliefCap, reliefAdd, reliefFloor), 4)

    return reliefAdd, reliefFloor, reliefCap
end

local function relieveContusion(ply)
    local org = getOrganism(ply)
    if not org or getContusionReliefNeed(ply) <= 0 then return false end

    local changed = false

    local function cap(field, maxValue)
        local current = tonumber(org[field]) or 0
        local newValue = math.min(current, maxValue)
        if newValue < current then
            org[field] = newValue
            changed = true
        end
    end

    local function reduce(field, amount)
        local current = tonumber(org[field]) or 0
        local newValue = math.max(current - amount, 0)
        if newValue < current then
            org[field] = newValue
            changed = true
        end
    end

    cap("shock", 30)
    reduce("immobilization", 10)
    reduce("painadd", 40)
    reduce("avgpain", 25)
    reduce("pain", 18)
    reduce("hurtadd", 15)
    reduce("hurt", 10)
    reduce("disorientation", 1.5)

    return changed
end

local function applyPainRelief(ply, row)
    local org = getOrganism(ply)
    if not org or getPainReliefNeed(ply) <= 0 then return false end

    local changed = false
    local reliefAdd, reliefFloor, reliefCap = getPainReliefSettings(row)
    local nextAnalgesiaAdd = math.min((tonumber(org.analgesiaAdd) or 0) + reliefAdd, reliefCap)
    if nextAnalgesiaAdd > (tonumber(org.analgesiaAdd) or 0) then
        org.analgesiaAdd = nextAnalgesiaAdd
        changed = true
    end

    local nextAnalgesia = math.max(tonumber(org.analgesia) or 0, reliefFloor)
    if nextAnalgesia > (tonumber(org.analgesia) or 0) then
        org.analgesia = nextAnalgesia
        changed = true
    end

    local function reduce(field, amount)
        local current = tonumber(org[field]) or 0
        local newValue = math.max(current - amount, 0)
        if newValue < current then
            org[field] = newValue
            changed = true
        end
    end

    if (tonumber(org.shock) or 0) > 35 then
        org.shock = 35
        changed = true
    end

    reduce("pain", 20)
    reduce("painadd", 20)
    reduce("avgpain", 15)

    return changed
end

hook.Add("Org Think", "ZScavMeds_PostTreatmentRecovery", function(owner, org, timeValue)
    if not (IsValid(owner) and owner:IsPlayer() and owner:Alive() and istable(org)) then return end

    local recoveryUntil = tonumber(org.zscav_treatment_recovery_until) or 0
    if recoveryUntil <= CurTime() then
        org.zscav_treatment_recovery_until = nil
        return
    end

    if not canUseTreatmentRecovery(org) then
        org.zscav_treatment_recovery_until = nil
        return
    end

    org.blood = math.Approach(tonumber(org.blood) or 0, 5000, timeValue * TREATMENT_RECOVERY_BLOOD_RATE)

    local oxygenCap = getTreatmentRecoveryOxygenCap(org)
    if istable(org.o2) then
        org.o2[1] = math.Approach(tonumber(org.o2[1]) or 0, oxygenCap, timeValue * TREATMENT_RECOVERY_OXYGEN_RATE)
    end

    if isfunction(owner.ResetNotification) then
        if (tonumber(org.blood) or 0) >= 2900 then
            owner:ResetNotification("blood2")
        end

        if (istable(org.o2) and (tonumber(org.o2[1]) or 0) >= 15) then
            owner:ResetNotification("lowoxy")
            owner:ResetNotification("lowoxy2")
            owner:ResetNotification("oxygen_lowintake")
        end
    end

    if (tonumber(org.blood) or 0) >= 4999 then
        if not istable(org.o2) or math.abs((tonumber(org.o2[1]) or 0) - oxygenCap) <= 0.1 then
            org.zscav_treatment_recovery_until = nil
        end
    end
end)

local function isHandsWeaponActive(ply)
    if not IsValid(ply) then return false end

    local activeWeapon = ply:GetActiveWeapon()
    return IsValid(activeWeapon) and activeWeapon:GetClass() == "weapon_hands_sh"
end

local RAGDOLL_SELF_SURGERY_PARTS = {
    left_leg = true,
    right_leg = true,
}

local SELF_RECOVERY_SURGERY_PARTS = {
    head = true,
    thorax = true,
    stomach = true,
}

local function canBypassHandsWeaponForSurgery(ply, patient, partID)
    if not (IsValid(ply) and IsValid(patient) and patient == ply) then return false end
    if not IsValid(ply.FakeRagdoll) then return false end
    if not RAGDOLL_SELF_SURGERY_PARTS[tostring(partID or "")] then return false end

    local org = getOrganism(ply)
    if not org or org.otrub then return false end

    return true
end

local function canBypassParalysisForSurgery(ply, patient, partID, state)
    if not (IsValid(ply) and IsValid(patient) and patient == ply) then return false end

    partID = tostring(partID or "")
    if not SELF_RECOVERY_SURGERY_PARTS[partID] then return false end

    if state == "spine2" then
        return partID == "thorax" and getCriticalSurgeryScore(ply, partID) > 0
    end

    if state == "spine3" then
        return partID == "stomach" and getCriticalSurgeryScore(ply, partID) > 0
    end

    if state == "canmove" or state == "incapacitated" then
        return getCriticalSurgeryScore(ply, partID) > 0
    end

    return false
end

local function clearPendingSurgery(ply)
    local st = pendingSurgery[ply]
    if not st then return nil end

    pendingSurgery[ply] = nil
    if st.timerName and st.timerName ~= "" then
        timer.Remove(st.timerName)
    end
    if IsValid(ply) then
        SurgeryProgressStop(ply)
    end

    return st
end

local function cancelPendingSurgery(ply, msg, switchDelay, msgKey, cooldown)
    local st = clearPendingSurgery(ply)
    if not st then return false end

    if switchDelay and switchDelay > 0 then
        ply.zscav_surgery_switch_block_until = CurTime() + switchDelay
    end

    if msg and msg ~= "" then
        noticePlayer(ply, msg, msgKey, cooldown)
    end

    return true
end

local function clampOrganDamage(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function getOrganDamageValue(value, index)
    if istable(value) then
        return clampOrganDamage(value[index or 1])
    end

    return clampOrganDamage(value)
end

local function setOrganDamageValue(org, field, value, index)
    if not (istable(org) and field) then return false end

    local current = org[field]
    local clamped = clampOrganDamage(value)

    if istable(current) then
        local slot = index or 1
        if getOrganDamageValue(current, slot) == clamped then return false end
        current[slot] = clamped
        return true
    end

    if clampOrganDamage(current) == clamped then return false end
    org[field] = clamped
    return true
end

local function capOrganNumericField(org, field, maxValue)
    if not (istable(org) and field) then return false end

    local current = tonumber(org[field]) or 0
    local newValue = math.min(current, tonumber(maxValue) or current)
    if newValue >= current then return false end

    org[field] = newValue
    return true
end

local function raiseOrganNumericField(org, field, minValue)
    if not (istable(org) and field) then return false end

    local current = tonumber(org[field]) or 0
    local newValue = math.max(current, tonumber(minValue) or current)
    if newValue <= current then return false end

    org[field] = newValue
    return true
end

local function restoreMobilityAfterSurgery(org)
    if not (istable(org) and not org.otrub) then return false end

    local changed = false
    local fakeSpine2, fakeSpine3 = getFakeSpineThresholds()

    if (tonumber(org.spine3) or 0) < fakeSpine3 and org.canmovehead == false then
        org.canmovehead = true
        changed = true
    end

    if (tonumber(org.spine2) or 0) < fakeSpine2 and (tonumber(org.spine3) or 0) < fakeSpine3 and org.canmove == false then
        org.canmove = true
        changed = true
    end

    if org.incapacitated and (tonumber(org.blood) or 0) >= 2900 and (tonumber(org.consciousness) or 1) > 0.4 then
        org.incapacitated = false
        changed = true
    end

    if org.needfake then
        org.needfake = false
        changed = true
    end

    return changed
end

-- Heals damage on each organ in the part. hpHealed is in HP (e.g. 45 hp on
-- a 85hp thorax). Returns the actual HP healed (capped to what was missing).
local function healPartHP(ply, partID, hpHealed, partMaxHP)
    if not (IsValid(ply) and partID and hpHealed > 0) then return 0 end

    local org = getOrganism(ply)
    if not org then return 0 end

    local organs = PART_TO_ORGANS[partID]
    if not organs then return 0 end

    local damageFracHealed = math.Clamp(hpHealed / math.max(partMaxHP or 1, 1), 0, 1)

    for _, field in ipairs(organs) do
        local current = getOrganDamageValue(org[field])
        if current > 0 then
            setOrganDamageValue(org, field, math.max(0, current - damageFracHealed))
        end
    end

    return hpHealed
end

-- Remove wound entries on the targeted part's bones. EFT statuses map as:
--   light_bleed = "regular" wound (ply.wounds)  with low intensity
--   heavy_bleed = arterial wound (ply.arterialwounds)
local function clearBleedingOnPart(ply, partID, partDef, kind)
    if not (IsValid(ply) and partID) then return false end

    local org = getOrganism(ply)
    if not org then return false end

    local boneSet = {}
    for _, boneName in ipairs(partDef.bones or {}) do
        boneSet[tostring(boneName or "")] = true
    end
    if next(boneSet) == nil then return false end

    local removed = false
    local clearedArteries = {}
    local function filter(list, collectArteries)
        if not istable(list) then return list end
        local out = {}
        for _, wound in ipairs(list) do
            if istable(wound) and boneSet[tostring(wound[4] or "")] then
                removed = true
                if collectArteries and isstring(wound[7]) and wound[7] ~= "" then
                    clearedArteries[wound[7]] = true
                end
            else
                out[#out + 1] = wound
            end
        end
        return out
    end

    if kind == "light_bleed" then
        org.wounds = filter(org.wounds, false)
    elseif kind == "heavy_bleed" then
        org.arterialwounds = filter(org.arterialwounds, true)
    elseif kind == "any_bleed" then
        org.wounds         = filter(org.wounds, false)
        org.arterialwounds = filter(org.arterialwounds, true)
    end

    for arteryField in pairs(clearedArteries) do
        if org[arteryField] ~= nil then
            org[arteryField] = 0
        end
    end

    return removed
end

-- Whether a given bleed type currently exists on the part. Used to short
-- circuit "stops bleed" items if there's nothing to stop.
local function partHasBleed(ply, partDef, kind)
    if not IsValid(ply) then return false end

    local org = getOrganism(ply)
    if not org then return false end

    local boneSet = {}
    for _, boneName in ipairs(partDef.bones or {}) do
        boneSet[tostring(boneName or "")] = true
    end
    if next(boneSet) == nil then return false end

    local function any(list)
        if not istable(list) then return false end
        for _, wound in ipairs(list) do
            if istable(wound) and boneSet[tostring(wound[4] or "")] then
                return true
            end
        end
        return false
    end

    if kind == "light_bleed" then return any(org.wounds) end
    if kind == "heavy_bleed" then return any(org.arterialwounds) end
    return false
end

-- Best-effort fracture clear. Homigrad versions vary on how fractures are
-- tracked; cover the two most common layouts:
--   * ply.organism[<field>_fracture] = bool
--   * ply.fractures = { [partID] = true }
local function clearFractureOnPart(ply, partID)
    if not IsValid(ply) then return false end

    local cleared = false

    local org = getOrganism(ply)
    if org then
        local organs = PART_TO_ORGANS[partID] or {}
        for _, field in ipairs(organs) do
            local key = tostring(field) .. "_fracture"
            if org[key] then
                org[key] = false
                cleared = true
            end
        end
    end

    if istable(ply.fractures) and ply.fractures[partID] then
        ply.fractures[partID] = nil
        cleared = true
    end

    return cleared
end

-- Restore a "blacked out" limb (Surgical Kit). We just clamp the part's
-- organ damage(s) below 1 and let healPartHP fill it from there.
local function restoreBlackedPart(ply, partID)
    if not (IsValid(ply) and partID) then return false end

    local organs = PART_TO_ORGANS[partID]
    local org = getOrganism(ply)
    if not (organs and org) then return false end

    local restored = false
    for _, field in ipairs(organs) do
        if getOrganDamageValue(org[field]) >= 1 then
            -- almost-dead but no longer destroyed
            setOrganDamageValue(org, field, 0.85)
            restored = true
        end
    end
    return restored
end

local function partIsAmputated(ply, partID)
    local org = getOrganism(ply)
    if not org then return false end

    local limbKey = PART_TO_AMPUTATION[partID]
    if not limbKey then return false end
    return org[limbKey .. "amputated"] == true
end

local function restoreAmputatedPart(ply, partID)
    local org = getOrganism(ply)
    if not org then return false end

    local limbKey = PART_TO_AMPUTATION[partID]
    if not limbKey then return false end

    local amputatedKey = limbKey .. "amputated"
    if org[amputatedKey] ~= true then return false end

    org[amputatedKey] = false

    local arteryKey = limbKey .. "artery"
    if org[arteryKey] ~= nil then
        org[arteryKey] = 0
    end

    for _, field in ipairs(PART_TO_ORGANS[partID] or {}) do
        setOrganDamageValue(org, field, 0.85)
    end

    return true
end

local function getCriticalSurgeryScore(ply, partID)
    local org = getOrganism(ply)
    if not org then return 0 end

    local fakeSpine2, fakeSpine3 = getFakeSpineThresholds()

    if partID == "thorax" then
        local internalBleed = tonumber(org.internalBleed) or 0
        local pneumothorax = tonumber(org.pneumothorax) or 0
        local spine2 = tonumber(org.spine2) or 0
        local trachea = getOrganDamageValue(org.trachea)
        local lungTissue = math.max(
            getOrganDamageValue(org.lungsL, 1),
            getOrganDamageValue(org.lungsR, 1)
        )
        local lungCollapse = math.max(
            getOrganDamageValue(org.lungsL, 2),
            getOrganDamageValue(org.lungsR, 2)
        )

        local score = 0
        if internalBleed > SURGERY_THORAX_INTERNAL_BLEED_MIN then
            score = math.max(score, 900 + internalBleed * 100)
        end
        if pneumothorax > SURGERY_THORAX_PNEUMOTHORAX_MIN then
            score = math.max(score, 920 + pneumothorax * 200)
        end
        if trachea > SURGERY_THORAX_TRACHEA_MIN then
            score = math.max(score, 880 + trachea * 150)
        end
        if lungTissue > SURGERY_THORAX_LUNG_TISSUE_MIN then
            score = math.max(score, 910 + lungTissue * 150)
        end
        if lungCollapse > SURGERY_THORAX_LUNG_COLLAPSE_MIN then
            score = math.max(score, 930 + lungCollapse * 150)
        end
        if spine2 >= fakeSpine2 then
            score = math.max(score, 980 + spine2 * 100)
        end

        return score
    end

    if partID == "stomach" then
        local spine3 = tonumber(org.spine3) or 0

        if spine3 >= fakeSpine3 then
            return 980 + spine3 * 100
        end

        return 0
    end

    if partID == "head" then
        local brain = getOrganDamageValue(org.brain)
        local skull = getOrganDamageValue(org.skull)
        local score = 0

        if brain > SURGERY_HEAD_BRAIN_MIN then
            score = math.max(score, 940 + brain * 200)
        end
        if skull > SURGERY_HEAD_SKULL_MIN then
            score = math.max(score, 880 + skull * 100)
        end

        return score
    end

    return 0
end

local function repairCriticalPartForSurgery(ply, partID)
    local org = getOrganism(ply)
    if not org then return false, nil end

    local changed = false
    local fakeSpine2, fakeSpine3 = getFakeSpineThresholds()

    if partID == "thorax" then
        changed = setOrganDamageValue(org, "chest", 0) or changed
        changed = setOrganDamageValue(org, "heart", 0) or changed
        changed = setOrganDamageValue(org, "trachea", 0) or changed
        changed = setOrganDamageValue(org, "lungsL", 0, 1) or changed
        changed = setOrganDamageValue(org, "lungsR", 0, 1) or changed
        changed = setOrganDamageValue(org, "lungsL", 0, 2) or changed
        changed = setOrganDamageValue(org, "lungsR", 0, 2) or changed

        if (tonumber(org.internalBleed) or 0) > 0 then
            org.internalBleed = 0
            changed = true
        end
        if (tonumber(org.internalBleedHeal) or 0) > 0 then
            org.internalBleedHeal = 0
            changed = true
        end
        if (tonumber(org.pneumothorax) or 0) > 0 then
            org.pneumothorax = 0
            changed = true
        end
        if org.heartstop then
            org.heartstop = false
            changed = true
        end
        if org.lungsfunction == false then
            org.lungsfunction = true
            changed = true
        end
        if (tonumber(org.spine2) or 0) >= fakeSpine2 then
            org.spine2 = 0
            changed = true
        end

        changed = restoreMobilityAfterSurgery(org) or changed

        if changed then
            return true, "Chest repaired. Breathing should hold now."
        end

        return false, nil
    end

    if partID == "stomach" then
        if (tonumber(org.spine3) or 0) >= fakeSpine3 then
            org.spine3 = 0
            changed = true
        end

        changed = restoreMobilityAfterSurgery(org) or changed

        if changed then
            return true, "Lower spine repaired. You should be able to move again."
        end

        return false, nil
    end

    if partID == "head" then
        changed = setOrganDamageValue(org, "skull", 0) or changed
        changed = setOrganDamageValue(org, "brain", 0) or changed

        changed = capOrganNumericField(org, "shock", 6) or changed
        changed = capOrganNumericField(org, "disorientation", 0.2) or changed
        changed = capOrganNumericField(org, "immobilization", 1) or changed
        changed = capOrganNumericField(org, "painadd", 6) or changed
        changed = capOrganNumericField(org, "avgpain", 12) or changed
        changed = capOrganNumericField(org, "pain", 15) or changed
        changed = capOrganNumericField(org, "hurtadd", 8) or changed
        changed = capOrganNumericField(org, "hurt", 8) or changed
        changed = raiseOrganNumericField(org, "consciousness", 0.95) or changed

        if org.heartstop and getOrganDamageValue(org.brain) == 0 then
            org.heartstop = false
            changed = true
        end

        changed = restoreMobilityAfterSurgery(org) or changed

        if changed then
            return true, "Head trauma repaired completely."
        end
    end

    return false, nil
end

-- Drain a pool item's HP pool by `cost`; returns true if drain succeeded.
local function drainPool(entry, row, cost)
    cost = math.max(tonumber(cost) or 0, 0)
    if cost <= 0 then return true end

    if row.pool_hp then
        local remaining = tonumber(entry.med_hp or row.pool_hp) or 0
        if remaining <= 0 then return false end

        entry.med_hp = math.max(0, remaining - cost)
        return true, entry.med_hp <= 0
    end

    if row.uses then
        local remaining = tonumber(entry.med_uses or row.uses) or 0
        if remaining <= 0 then return false end

        entry.med_uses = remaining - 1
        return true, entry.med_uses <= 0
    end

    if row.single_use then
        return true, true
    end

    return true, false
end

-- ---------------------------------------------------------------------
-- Inventory helpers (forward-declared so ApplyMedical can use them)
-- ---------------------------------------------------------------------
function ZScavMeds._RemoveEntry(ply, inv, target)
    if not (istable(inv) and istable(target)) then return end
    local list = inv[target.grid]
    if not istable(list) then return end

    -- Re-validate the index in case anything reordered the list mid-action.
    if list[target.index] == target.entry then
        table.remove(list, target.index)
    else
        for idx, candidate in ipairs(list) do
            if candidate == target.entry then
                table.remove(list, idx)
                break
            end
        end
    end
end

function ZScavMeds._SyncInv(ply)
    local helpers = ZSCAV and ZSCAV.ServerHelpers
    if helpers and isfunction(helpers.SyncInventory) then
        helpers.SyncInventory(ply)
    end
end

function ZScavMeds._SyncMedicalState(ply)
    local org = getOrganism(ply)
    if not org then return end

    org.wounds = istable(org.wounds) and org.wounds or {}
    org.arterialwounds = istable(org.arterialwounds) and org.arterialwounds or {}

    ply.wounds = org.wounds
    ply.arterialwounds = org.arterialwounds

    ply:SetNetVar("wounds", org.wounds)
    ply:SetNetVar("arterialwounds", org.arterialwounds)

    if IsValid(ply.RagdollDeath) then
        ply.RagdollDeath:SetNetVar("wounds", org.wounds)
        ply.RagdollDeath:SetNetVar("arterialwounds", org.arterialwounds)
    end

    if IsValid(ply.FakeRagdoll) then
        ply.FakeRagdoll:SetNetVar("wounds", org.wounds)
        ply.FakeRagdoll:SetNetVar("arterialwounds", org.arterialwounds)
    end

    if hg and hg.send_bareinfo then
        hg.send_bareinfo(org)
    end

    if hg and hg.send_organism then
        hg.send_organism(org, ply)
    end
end

-- ---------------------------------------------------------------------
-- Core healing pipeline (called by both hooks).
--
-- target = {
--   part  = partDef,
--   grid  = "pocket"|"vest"|...,
--   index = N,
--   entry = inventory entry table,
-- }
--
-- Return values:
--   true        = consumed silently
--   string      = consumed, caller should turn it into a Notice
--   false / nil = nothing happened
-- ---------------------------------------------------------------------
function ZScavMeds.ApplyMedical(ply, inv, target, row)
    if not (IsValid(ply) and istable(target) and istable(target.entry)) then
        return nil
    end

    row = row or (ZSCAV.GetMedicalEFTData and ZSCAV:GetMedicalEFTData(target.entry.class)) or nil
    if not row then return nil end

    local patient = IsValid(target.patient) and target.patient or ply
    if not IsValid(patient) then return nil end

    local part    = target.part
    local partID  = part and part.id
    if not (partID and PART_TO_ORGANS[partID]) then
        return "That body part can't be treated with " .. tostring(row.print_name or row.class) .. "."
    end

    local treats = row.treats or {}
    local entry  = target.entry
    local didSomething = false
    local didSurgicalRestore = false
    local restoredSurgicalPartID = nil
    local restoredSurgicalPartLabel = nil
    local restoredSurgicalAmputated = false
    local resultLines  = {}
    local treatingOther = patient ~= ply

    local function syncMedicalAndInventory()
        queueTreatmentRecovery(patient)
        ZScavMeds._SyncMedicalState(patient)
        ZScavMeds._SyncInv(ply)
    end

    local function getRemainingSurgeryParts(amputatedOnly)
        if not (IsValid(patient) and ZSCAV.GetHealthPartDefinitions) then return {} end

        local out = {}
        for _, partDef in ipairs(ZSCAV:GetHealthPartDefinitions() or {}) do
            if istable(partDef) and partDef.id then
                local snap = getPartHealthSnapshot(patient, partDef.id, partDef)
                local stillNeedsSurgery = snap.amputated or snap.blacked
                if stillNeedsSurgery and (not amputatedOnly or snap.amputated) then
                    out[#out + 1] = partDef
                end
            end
        end

        return out
    end

    local function getSpentItemLine()
        local category = tostring(row.category or "")

        if category == "surgical" then
            if not treatingOther and didSurgicalRestore then
                local remainingAmputated = getRemainingSurgeryParts(true)
                local remainingSurgical = (#remainingAmputated > 0) and remainingAmputated or getRemainingSurgeryParts(false)
                local nextPart = remainingSurgical[1]
                local nextPartLabel = string.lower(tostring(nextPart and nextPart.label or "limb"))

                if #remainingAmputated > 0 then
                    local restoredWasLeg = restoredSurgicalPartID == "left_leg" or restoredSurgicalPartID == "right_leg"
                    local remainingIsLeg = nextPart and (nextPart.id == "left_leg" or nextPart.id == "right_leg")

                    if restoredSurgicalAmputated and restoredWasLeg and #remainingAmputated == 1 and remainingIsLeg then
                        return "Fuck. One leg's back and the other one's still gone. Need another kit, now."
                    end

                    if #remainingAmputated == 1 then
                        return ("Fuck. Kit's empty and my %s is still gone."):format(nextPartLabel)
                    end

                    return "Fuck. Kit's empty and parts of me are still missing."
                end

                if #remainingSurgical > 0 then
                    if #remainingSurgical == 1 then
                        return ("Shit. That's it and my %s is still ruined."):format(nextPartLabel)
                    end

                    return "Shit. That's it and I'm still not put back together."
                end
            end

            return "That's all the kit can do."
        elseif category == "splint" then
            return "That's all this splint's got."
        elseif category == "tourniquet" then
            return "That's all I've got for that."
        elseif category == "bandage" then
            return "That's the last bandage."
        end

        return "That's the last of it."
    end

    local function exhaustedReturn()
        ZScavMeds._RemoveEntry(ply, inv, target)
        resultLines[#resultLines + 1] = getSpentItemLine()
        syncMedicalAndInventory()
        return table.concat(resultLines, " ")
    end

    -- 1) Stop heavy bleed first (priority for tourniquets).
    if treats.heavy_bleed and partHasBleed(patient, part, "heavy_bleed") then
        local ok, exhausted = drainPool(entry, row, treats.heavy_bleed)
        if ok then
            if clearBleedingOnPart(patient, partID, part, "heavy_bleed") then
                didSomething = true
                resultLines[#resultLines + 1] = "Heavy bleed stopped."
            end
            if exhausted then return exhaustedReturn() end
        end
    end

    -- 2) Stop light bleed.
    if treats.light_bleed and partHasBleed(patient, part, "light_bleed") then
        local ok, exhausted = drainPool(entry, row, treats.light_bleed)
        if ok then
            if clearBleedingOnPart(patient, partID, part, "light_bleed") then
                didSomething = true
                resultLines[#resultLines + 1] = "Light bleed stopped."
            end
            if exhausted then return exhaustedReturn() end
        end
    end

    -- 3) Fix fracture.
    if treats.fracture then
        local ok, exhausted = drainPool(entry, row, treats.fracture)
        if ok and clearFractureOnPart(patient, partID) then
            didSomething = true
            resultLines[#resultLines + 1] = "Fracture stabilised."
            if exhausted then return exhaustedReturn() end
        elseif row.category == "splint" and not didSomething then
            return "No fracture on " .. string.lower(part.label or partID) .. "."
        end
    end

    -- 4) Treat systemic post-impact shock / bruising.
    if treats.contusion ~= nil and getContusionReliefNeed(patient) > 0 then
        local ok, exhausted = drainPool(entry, row, treats.contusion)
        if ok and relieveContusion(patient) then
            didSomething = true
            resultLines[#resultLines + 1] = treatingOther
                and "That should settle the worst of the impact."
                or "That should settle the worst of the impact."
            if exhausted then return exhaustedReturn() end
        end
    end

    -- 5) Apply pain relief.
    if treats.pain ~= nil and getPainReliefNeed(patient) > 0 then
        local ok, exhausted = drainPool(entry, row, treats.pain)
        if ok and applyPainRelief(patient, row) then
            didSomething = true
            resultLines[#resultLines + 1] = treatingOther
                and "That should take the edge off."
                or "Pain's starting to ease."
            if exhausted then return exhaustedReturn() end
        end
    end

    -- 6) Surgical Kit: restore blacked-out limb (and apply a light bleed).
    if treats.restore_blacked then
        local ok, exhausted = drainPool(entry, row, treats.restore_blacked)
        local repairedCritical, criticalResultLine = false, nil
        local restoredAmputated = ok and restoreAmputatedPart(patient, partID) or false
        local restoredBlacked = ok and restoreBlackedPart(patient, partID) or false
        if ok then
            repairedCritical, criticalResultLine = repairCriticalPartForSurgery(patient, partID)
        end
        if ok and (repairedCritical or restoredAmputated or restoredBlacked) then
            didSomething = true
            didSurgicalRestore = true
            restoredSurgicalPartID = partID
            restoredSurgicalPartLabel = part.label or partID
            restoredSurgicalAmputated = restoredAmputated
            clearBleedingOnPart(patient, partID, part, "any_bleed")

            local surgeryResultLine = criticalResultLine
                or (restoredAmputated
                    and (treatingOther and "That limb's back." or "Limb's back.")
                    or (treatingOther and "That limb should hold now." or "That limb's usable again."))

            if treats.applies_light_bleed and not repairedCritical and istable(part.bones) and part.bones[1] then
                local org = getOrganism(patient)
                org.wounds = istable(org.wounds) and org.wounds or {}
                org.wounds[#org.wounds + 1] = { 8, Vector(0,0,0), Angle(0,0,0), part.bones[1], CurTime() }
                surgeryResultLine = treatingOther
                    and "Still bleeding a little. They'll need gauze."
                    or "Still bleeding a little, gonna need gauze."
            end

            resultLines[#resultLines + 1] = surgeryResultLine

            if exhausted then return exhaustedReturn() end
        end
    end

    if didSurgicalRestore then
        syncMedicalAndInventory()
        return table.concat(resultLines, " ")
    end

    -- 7) HP heal from pool (medkits + bandages with instant_hp).
    if row.pool_hp then
        local partMax  = tonumber(part.max_hp) or 0
        local remaining = tonumber(entry.med_hp or row.pool_hp) or 0
        if remaining > 0 and partMax > 0 then
            local org = patient.organism or {}
            local damageFrac = 0
            for _, field in ipairs(PART_TO_ORGANS[partID] or {}) do
                local v = getOrganDamageValue(org[field])
                if v > damageFrac then damageFrac = v end
            end
            local missingHP = math.Round(partMax * damageFrac)

            if missingHP > 0 then
                local toHeal = math.min(missingHP, remaining)
                local instant = tonumber(row.instant_hp) or 0
                if instant > 0 then
                    toHeal = math.min(missingHP, math.min(remaining, instant))
                end

                if toHeal > 0 then
                    healPartHP(patient, partID, toHeal, partMax)
                    if patient.SetHealth and patient.Health then
                        local maxH = patient:GetMaxHealth()
                        patient:SetHealth(math.min(maxH, patient:Health() + toHeal))
                    end

                    local _, exhausted = drainPool(entry, row, toHeal)
                    didSomething = true
                    resultLines[#resultLines + 1] = ("Healed %d HP on %s."):format(
                        toHeal, string.lower(part.label or partID))
                    if exhausted then return exhaustedReturn() end
                end
            end
        end
    end

    -- 6) Single-use bandage with no pool: consume on use only if it did
    --    something (we don't want to burn a bandage on a healthy part).
    if row.single_use and didSomething then
        ZScavMeds._RemoveEntry(ply, inv, target)
        resultLines[#resultLines + 1] = getSpentItemLine()
    end

    if didSomething then
        syncMedicalAndInventory()
        return table.concat(resultLines, " ")
    end

    return "Nothing to treat on " .. string.lower(part.label or partID) .. "."
end

-- ---------------------------------------------------------------------
-- Body-part picker for the hotbar / quickslot path.
--
-- Strategy: enumerate eligible parts (per profile.target_parts), score each,
-- pick the highest score. Items prioritise the status they actually treat:
--   * tourniquet → only parts with arterial bleed score > 0
--   * splint     → only parts with a fracture score > 0
--   * bandage    → only parts with a regular bleed score > 0
--   * surgical   → only parts that are blacked-out (damage_frac >= 1)
--   * medkits    → parts ranked by missing HP (with bleed/fracture bumps)
-- ---------------------------------------------------------------------
local function getProfileTargets(profile)
    local targets = profile and profile.target_parts
    if targets == nil or targets == "any" then
        return PART_TO_ORGANS
    end
    if not istable(targets) then return PART_TO_ORGANS end

    local out = {}
    if next(targets) then
        for k, v in pairs(targets) do
            if v == true then
                out[tostring(k):lower()] = PART_TO_ORGANS[tostring(k):lower()]
            elseif type(k) == "number" then
                local key = tostring(v):lower()
                if PART_TO_ORGANS[key] then out[key] = PART_TO_ORGANS[key] end
            end
        end
    end
    if not next(out) then return PART_TO_ORGANS end
    return out
end

local function getPartHealthSnapshot(ply, partID, partDef)
    local org = ply.organism or {}
    local damageFrac = 0
    for _, field in ipairs(PART_TO_ORGANS[partID] or {}) do
        local v = getOrganDamageValue(org[field])
        if v > damageFrac then damageFrac = v end
    end
    local maxHP = tonumber(partDef.max_hp) or 0
    local missingHP = math.Round(maxHP * damageFrac)

    return {
        damage_frac = damageFrac,
        missing_hp  = missingHP,
        max_hp      = maxHP,
        light_bleed = partHasBleed(ply, partDef, "light_bleed"),
        heavy_bleed = partHasBleed(ply, partDef, "heavy_bleed"),
        amputated   = partIsAmputated(ply, partID),
        blacked     = damageFrac >= 1,
    }
end

local function partNeedsSurgery(ply, partDef)
    if not (IsValid(ply) and istable(partDef) and partDef.id) then return false end

    local snap = getPartHealthSnapshot(ply, partDef.id, partDef)
    return snap.amputated or snap.blacked or getCriticalSurgeryScore(ply, partDef.id) > 0
end

local function resolvePendingSurgeryTarget(ply, st)
    if not (IsValid(ply) and istable(st)) then return nil, nil end

    local inv = ply.zscav_inv
    if not istable(inv) then return nil, nil end

    local part = ZSCAV.GetHealthPartDef and ZSCAV:GetHealthPartDef(st.partID) or nil
    if not part and ZSCAV.GetHealthPartDefinitions then
        for _, candidate in ipairs(ZSCAV:GetHealthPartDefinitions() or {}) do
            if candidate.id == st.partID then
                part = candidate
                break
            end
        end
    end

    if not (istable(part) and part.id) then return inv, nil end

    local list = inv[st.grid]
    if not istable(list) then return inv, nil end

    local entryUID = tostring(st.entryUID or "")
    local entryWeaponUID = tostring(st.entryWeaponUID or "")

    local function matches(entry)
        if not (istable(entry) and entry.class == st.entryClass) then return false end
        if entry == st.entryRef then return true end
        if entryUID ~= "" and tostring(entry.uid or "") == entryUID then return true end
        if entryWeaponUID ~= "" and tostring(entry.weapon_uid or "") == entryWeaponUID then return true end
        return false
    end

    local wantedIndex = math.floor(tonumber(st.index) or 0)
    if wantedIndex > 0 then
        local candidate = list[wantedIndex]
        if matches(candidate) then
            return inv, {
                part = part,
                grid = st.grid,
                index = wantedIndex,
                entry = candidate,
                patient = st.patient,
            }
        end
    end

    for index, entry in ipairs(list) do
        if matches(entry) then
            return inv, {
                part = part,
                grid = st.grid,
                index = index,
                entry = entry,
                patient = st.patient,
            }
        end
    end

    return inv, nil
end

local function startPendingSurgery(ply, inv, target, row)
    if pendingSurgery[ply] then
        noticePlayer(ply, "Already in surgery.", "zscav_surgery_busy", 0.75)
        return false
    end

    if not (istable(target) and istable(target.part) and target.part.id and istable(target.entry)) then
        return nil
    end

    local patient = IsValid(target.patient) and target.patient or ply
    if not IsValid(patient) then
        noticePlayer(ply, "Can't treat them right now.", "zscav_surgery_patient_missing", 0.75)
        return false
    end

    local paralysisState = getSurgeryParalysisState(ply)
    if paralysisState and not canBypassParalysisForSurgery(ply, patient, target.part.id, paralysisState) then
        local line = getParalyzedSurgeryLine(ply, target.part.id, paralysisState)
        if line then
            noticePlayer(ply, line, "zscav_surgery_paralyzed_" .. paralysisState, 1.5)
        end
        return false
    end

    if ZSCAV.CanPlayerUseInventory and not ZSCAV:CanPlayerUseInventory(ply) then
        noticePlayer(ply, "You can't do surgery right now.", "zscav_surgery_blocked", 0.75)
        return false
    end

    local canIgnoreHandsWeapon = canBypassHandsWeaponForSurgery(ply, patient, target.part.id)
    if not isHandsWeaponActive(ply) and not canIgnoreHandsWeapon then
        noticePlayer(ply, getHandsRequiredLine(ply), "zscav_surgery_hands", 1.2)
        return false
    end

    if not partNeedsSurgery(patient, target.part) then
        noticePlayer(ply,
            "Nothing to treat on " .. string.lower(target.part.label or target.part.id) .. ".",
            "zscav_surgery_empty_" .. tostring(target.part.id or "part"),
            0.75)
        return false
    end

    local st = {
        grid = tostring(target.grid or ""),
        index = math.floor(tonumber(target.index) or 0),
        entryRef = target.entry,
        entryClass = tostring(target.entry.class or row.class or ""),
        entryUID = tostring(target.entry.uid or ""),
        entryWeaponUID = tostring(target.entry.weapon_uid or ""),
        partID = tostring(target.part.id or ""),
        partLabel = tostring(target.part.label or target.part.id or ""),
        class = tostring(target.entry.class or row.class or ""),
        row = row,
        patient = patient,
        startedAt = CurTime(),
        finishAt = CurTime() + SURGERY_DURATION,
        startPos = ply:GetPos(),
        barkOffsets = SURGERY_PROGRESS_BARK_OFFSETS,
        barkIndex = 1,
        barkSource = getSurgeryNarrationSource(ply, patient, SURGERY_PROGRESS_LINES, SURGERY_PATIENT_PROGRESS_LINES),
        cancelSource = getSurgeryNarrationSource(ply, patient, SURGERY_CANCEL_LINES, SURGERY_PATIENT_CANCEL_LINES),
        timerName = "ZScavSurgery_" .. tostring(ply:EntIndex()),
    }

    st.barkPool = getSurgeryLinePool(st.barkSource, target.part.id)
    st.cancelPool = getSurgeryLinePool(st.cancelSource, target.part.id)

    pendingSurgery[ply] = st
    SurgeryProgressStart(ply, SURGERY_DURATION, st.class, st.partLabel)

    timer.Create(st.timerName, 0.05, 0, function()
        if not IsValid(ply) then
            clearPendingSurgery(ply)
            return
        end

        local activeState = pendingSurgery[ply]
        if activeState ~= st then
            timer.Remove(st.timerName)
            return
        end

        if not ZSCAV:IsActive() or not ply:Alive() then
            clearPendingSurgery(ply)
            return
        end

        local liveParalysisState = getSurgeryParalysisState(ply)
        if liveParalysisState and not canBypassParalysisForSurgery(ply, st.patient, st.partID, liveParalysisState) then
            cancelPendingSurgery(
                ply,
                getParalyzedSurgeryLine(ply, st.partID, liveParalysisState),
                nil,
                "zscav_surgery_paralyzed_" .. liveParalysisState,
                1.5)
            return
        end

        if ZSCAV.CanPlayerUseInventory and not ZSCAV:CanPlayerUseInventory(ply) then
            cancelPendingSurgery(ply, pickRandomLine(st.cancelPool) or "Shit, not now..", nil, "zscav_surgery_cancel", 1.2)
            return
        end

        if not isHandsWeaponActive(ply) and not canBypassHandsWeaponForSurgery(ply, st.patient, st.partID) then
            cancelPendingSurgery(ply, pickRandomLine(st.cancelPool) or "Shit, not now..", nil, "zscav_surgery_cancel_hands", 1.2)
            return
        end

        if st.startPos:DistToSqr(ply:GetPos()) > SURGERY_MOVE_CANCEL_DIST_SQR then
            cancelPendingSurgery(ply, pickRandomLine(st.cancelPool) or "Shit, not now..", nil, "zscav_surgery_cancel_move", 1.2)
            return
        end

        local barkOffset = st.barkOffsets[st.barkIndex]
        if barkOffset and CurTime() >= (st.startedAt + barkOffset) then
            local line = popRandomLine(st.barkPool) or pickRandomLine(getSurgeryLinePool(st.barkSource or SURGERY_PROGRESS_LINES, st.partID))
            if line and line ~= "" then
                noticePlayer(ply, line, "zscav_surgery_progress_" .. tostring(st.barkIndex), 0.15)
            end
            st.barkIndex = st.barkIndex + 1
        end

        if CurTime() < st.finishAt then return end

        clearPendingSurgery(ply)

        local currentInv, currentTarget = resolvePendingSurgeryTarget(ply, st)
        if not currentTarget then
            noticePlayer(ply, "Surgery interrupted.", "zscav_surgery_interrupted", 0.75)
            return
        end

        local currentPatient = IsValid(st.patient) and st.patient or nil
        if not IsValid(currentPatient) then
            noticePlayer(ply, "Can't treat them right now.", "zscav_surgery_patient_missing_finish", 0.75)
            return
        end

        if not partNeedsSurgery(currentPatient, currentTarget.part) then
            noticePlayer(ply,
                "Nothing to treat on " .. string.lower(currentTarget.part.label or currentTarget.part.id) .. ".",
                "zscav_surgery_empty_finish_" .. tostring(currentTarget.part.id or "part"),
                0.75)
            return
        end

        currentTarget.patient = currentPatient
        local result = ZScavMeds.ApplyMedical(ply, currentInv, currentTarget, st.row)
        if result == nil or result == false then
            noticePlayer(ply, "Could not complete surgery.", "zscav_surgery_failed", 0.75)
            return
        end

        if isstring(result) and result ~= "" then
            noticePlayer(ply, result, "zscav_surgery_result", 0.25)
        end

        if math.random(100) == 1 then
            noticePlayer(ply, SURGERY_SUCCESS_GAG_LINE, "zscav_surgery_gag", 0.25)
        end
    end)

    return true
end

function ZScavMeds.PickBestPartForItem(ply, row, profile)
    if not (IsValid(ply) and istable(row)) then return nil end

    local partDefs = ZSCAV.GetHealthPartDefinitions and ZSCAV:GetHealthPartDefinitions() or {}
    if #partDefs == 0 then return nil end

    local eligible = getProfileTargets(profile)
    local treats = row.treats or {}
    local category = tostring(row.category or "")
    local systemicMedScore = 0

    if category == "medkit" then
        if treats.contusion ~= nil then
            systemicMedScore = systemicMedScore + getContusionReliefNeed(ply)
        end

        if treats.pain ~= nil then
            systemicMedScore = systemicMedScore + getPainReliefNeed(ply)
        end
    end

    local bestPart, bestScore

    for _, partDef in ipairs(partDefs) do
        local pid = partDef.id
        if eligible[pid] then
            local snap  = getPartHealthSnapshot(ply, pid, partDef)
            local score = 0

            if category == "tourniquet" then
                if snap.heavy_bleed then score = 1000 end
            elseif category == "splint" then
                -- We can't easily tell if this part is fractured (Homigrad
                -- variations) — score by missing HP as a heuristic for
                -- "this limb has been hit". The handler will short-circuit
                -- with "no fracture" if there isn't one.
                if snap.missing_hp > 0 or snap.heavy_bleed then
                    score = 800 + snap.missing_hp
                end
            elseif category == "bandage" then
                if snap.light_bleed then score = 1000 end
            elseif category == "surgical" then
                if snap.blacked or snap.amputated then
                    score = 1000 + (snap.amputated and 100 or 0)
                end
                score = math.max(score, getCriticalSurgeryScore(ply, pid))
            else  -- medkit
                score = snap.missing_hp
                if snap.light_bleed then score = score + 30 end
                if snap.heavy_bleed and treats.heavy_bleed then score = score + 200 end
                if treats.fracture and snap.missing_hp > 0 then score = score + 20 end
                if systemicMedScore > 0 then score = score + systemicMedScore end
            end

            -- Prefer lethal parts (head/thorax) at score ties so the player
            -- doesn't waste a Grizzly on a leg when the chest is bleeding.
            if partDef.lethal then score = score + 0.1 end

            if score > 0 and (bestScore == nil or score > bestScore) then
                bestScore = score
                bestPart  = partDef
            end
        end
    end

    return bestPart
end

-- ---------------------------------------------------------------------
-- Hook handlers
-- ---------------------------------------------------------------------

-- Health-tab drag-drop path.
hook.Add("ZSCAV_UseMedicalTarget", "ZScavMeds_HealHandler",
    function(ply, inv, target, profile, args)
        local row = ZSCAV.GetMedicalEFTData and ZSCAV:GetMedicalEFTData(target.entry.class) or nil
        if not row then return nil end

        if pendingSurgery[ply] then
            noticePlayer(ply, "Already in surgery.", "zscav_surgery_busy", 0.75)
            return false
        end

        if tostring(row.category or "") == "surgical" then
            return startPendingSurgery(ply, inv, target, row)
        end

        return ZScavMeds.ApplyMedical(ply, inv, target, row)
    end)

-- Hotbar / quickslot path.
hook.Add("ZSCAV_UseMedicalQuickslot", "ZScavMeds_QuickslotHandler",
    function(ply, inv, target)
        if not (IsValid(ply) and istable(target) and istable(target.entry)) then
            return nil
        end

        if pendingSurgery[ply] then
            noticePlayer(ply, "Already in surgery.", "zscav_surgery_busy", 0.75)
            return false
        end

        local row = ZSCAV.GetMedicalEFTData and ZSCAV:GetMedicalEFTData(target.entry.class) or nil
        if not row then return nil end

        local profile = ZSCAV.GetMedicalUseProfile and ZSCAV:GetMedicalUseProfile(target.entry.class) or nil
        local pickedPart = ZScavMeds.PickBestPartForItem(ply, row, profile)

        if not pickedPart then
            -- Nothing to do — clearer message per category.
            local cat = tostring(row.category or "")
            if cat == "tourniquet" then
                return "No heavy bleed on any limb."
            elseif cat == "splint" then
                return "No injured limb to splint."
            elseif cat == "bandage" then
                return "No light bleed to bandage."
            elseif cat == "surgical" then
                noticePlayer(ply, "No blacked-out or amputated limb to restore.", "zscav_surgery_no_candidate", 0.75)
                return false
            end
            return "Nothing to treat right now."
        end

        local synthetic = {
            part  = pickedPart,
            grid  = target.grid,
            index = target.index,
            entry = target.entry,
        }

        if tostring(row.category or "") == "surgical" then
            return startPendingSurgery(ply, inv, synthetic, row)
        end

        local result = ZScavMeds.ApplyMedical(ply, inv, synthetic, row)
        if result == nil then
            return "Could not apply " .. tostring(row.print_name or row.class) .. "."
        end
        return result
    end)

hook.Add("PlayerSwitchWeapon", "ZScavMeds_CancelSurgeryOnSwitch", function(ply, oldWep, newWep)
    if not IsValid(ply) then return end

    local newClass = IsValid(newWep) and tostring(newWep:GetClass() or "") or ""
    local lockUntil = tonumber(ply.zscav_surgery_switch_block_until) or 0
    if lockUntil > CurTime() then
        if newClass ~= "weapon_hands_sh" then
            return true
        end
        return
    end

    if not pendingSurgery[ply] then return end
    if newClass == "" or newClass == "weapon_hands_sh" then return end

    cancelPendingSurgery(
        ply,
        pickRandomLine(pendingSurgery[ply].cancelPool) or "Shit, not now..",
        SURGERY_SWITCH_LOCK_DURATION,
        "zscav_surgery_cancel_switch",
        1.2)
    return true
end)

hook.Add("PlayerDisconnected", "ZScavMeds_ClearPendingSurgeryOnLeave", function(ply)
    clearPendingSurgery(ply)
end)

print("[ZScavMeds] ZSCAV_UseMedicalTarget + ZSCAV_UseMedicalQuickslot handlers registered.")
