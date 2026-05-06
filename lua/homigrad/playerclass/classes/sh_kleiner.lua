local CLASS = player.RegClass("drkleiner")
local random_lines = {"vo/k_lab/kl_almostforgot.wav", "vo/k_lab/kl_blast.wav", "vo/k_lab/kl_bonvoyage.wav", "vo/k_lab/kl_coaxherout.wav", "vo/k_lab/kl_credit.wav", "vo/k_lab/kl_diditwork.wav", "vo/k_lab/kl_excellent.wav", "vo/k_lab/kl_fewmoments01.wav", "vo/k_lab/kl_fiddlesticks.wav", "vo/k_lab/kl_finalsequence02.wav", "vo/k_lab/kl_fruitlessly.wav", "vo/k_lab/kl_getoutrun02.wav", "vo/k_lab/kl_hesnotthere.wav", "vo/k_lab/kl_initializing.wav", "vo/k_lab/kl_initializing02.wav", "vo/k_lab/kl_islamarr.wav", "vo/k_lab/kl_lamarr.wav", "vo/k_lab/kl_masslessfieldflux.wav", "vo/k_lab/kl_nonsense.wav", "vo/k_lab/kl_nownow01.wav", "vo/k_lab/kl_ohdear.wav", "vo/k_lab/kl_packing01.wav", "vo/k_lab/kl_packing02.wav", "vo/k_lab/kl_redletterday01.wav", "vo/k_lab/kl_redletterday02.wav", "vo/k_lab/kl_relieved.wav", "vo/k_lab/kl_thenwhere.wav", "vo/k_lab/kl_whatisit.wav", "vo/k_lab/kl_wishiknew.wav", "vo/k_lab/kl_dearme.wav"}
local pain_lines = {"vo/k_lab/kl_ahhhh.wav", "vo/k_lab/kl_getoutrun03.wav", "vo/k_lab/kl_hedyno03.wav", "vo/k_lab/kl_interference.wav"}
if SERVER then
    local kleinerSwearReplacements = {
        ["fuck"] = "fiddlesticks",
        ["shit"] = "dear me",
        ["damn"] = "oh dear",
        ["dammit"] = "fiddlesticks",
        ["hell"] = "goodness",
        ["fucking"] = "",
        ["bastard"] = "ruffian",
        ["ass"] = "behind",
        ["bitch"] = "difficult person",
        ["crap"] = "nonsense",
        ["god"] = "goodness",
        ["jesus"] = "goodness",
        ["christ"] = "goodness",
        ["bloody"] = "very",
        ["piss"] = "upset",
        ["cunt"] = "unpleasant person",
        ["whore"] = "lady of the night",
        ["slut"] = "promiscuous individual",
        ["FUCK"] = "FIDDLESTICKS",
        ["SHIT"] = "DEAR ME",
        ["DAMN"] = "OH DEAR",
        ["DAMMIT"] = "FIDDLESTICKS",
        ["HELL"] = "GOODNESS",
        ["FUCKING"] = "",
        ["BASTARD"] = "RUFFIAN",
        ["ASS"] = "BEHIND",
        ["BITCH"] = "DIFFICULT PERSON",
        ["CRAP"] = "NONSENSE",
        ["GOD"] = "GOODNESS",
        ["JESUS"] = "GOODNESS",
        ["CHRIST"] = "GOODNESS",
        ["BLOODY"] = "VERY",
        ["PISS"] = "UPSET",
        ["CUNT"] = "UNPLEASANT PERSON",
        ["WHORE"] = "LADY OF THE NIGHT",
        ["SLUT"] = "PROMISCUOUS INDIVIDUAL",
    }
    local function KleinerCleanText(text)
        if not isstring(text) then return text end
        for swear, repl in pairs(kleinerSwearReplacements) do
            text = string.gsub(text, "(%f[%a]" .. swear .. "%f[%A])", repl)
            local capSwear = swear:sub(1,1):upper() .. swear:sub(2)
            text = string.gsub(text, "(%f[%a]" .. capSwear .. "%f[%A])", repl:sub(1,1):upper() .. repl:sub(2))
        end
        return text
    end
    local kleinerBoneMessages = {
        ["brokearm"] = {
            "Oh dear, my arm appears to be fractured.",
            "I believe my arm has sustained a break.",
            "Fiddlesticks, that's not supposed to bend that way.",
            "A fracture in the upper extremity."
        },
        ["brokelarm"] = {
            "My left arm has suffered a fracture.",
            "The left humerus seems to be compromised.",
            "I shall need to immobilize my left arm."
        },
        ["brokearm"] = {
            "My right arm is broken, how inconvenient.",
            "A fracture in the right arm.",
            "This will make fine motor tasks quite difficult."
        },
        ["brokeleg"] = {
            "Oh my, my leg has broken.",
            "I appear to have fractured my lower limb.",
            "Walking will be rather challenging now."
        },
        ["brokelleg"] = {
            "My left leg is fractured.",
            "The left femur seems damaged.",
            "I shall need a crutch."
        },
        ["brokerleg"] = {
            "My right leg is broken.",
            "A fracture in the right leg.",
            "Ambulation will be problematic."
        },
        ["dislocatedarm"] = {
            "My arm has become dislocated.",
            "The shoulder joint is out of alignment.",
            "I must relocate this carefully."
        },
        ["dislocatedlarm"] = {
            "My left shoulder is dislocated.",
            "The left glenohumeral joint is displaced."
        },
        ["dislocatedrarm"] = {
            "My right shoulder is dislocated.",
            "The right arm is not in its proper socket."
        },
        ["dislocatedleg"] = {
            "My leg has become dislocated.",
            "The hip joint seems misaligned.",
            "This will impede my locomotion."
        },
        ["dislocatedlleg"] = {
            "My left hip is dislocated."
        },
        ["dislocatedrleg"] = {
            "My right hip is dislocated."
        },
        ["dislocatedjaw"] = {
            "My jaw is dislocated, how bothersome.",
            "I cannot enunciate properly.",
            "The temporomandibular joint has slipped."
        }
    }
    local function GetKleinerBoneMsg(key)
        local msgs = kleinerBoneMessages[key]
        if msgs then
            return msgs[math.random(#msgs)]
        end
        return nil
    end
    local old_get_status = hg.get_status_message
    function hg.get_status_message(ply)
        if not IsValid(ply) or ply.PlayerClassName ~= "drkleiner" then
            return old_get_status(ply)
        end
        local defaultMsg = old_get_status(ply)
        if defaultMsg ~= "" then
            return KleinerCleanText(defaultMsg)
        end
        local org = ply.organism
        if not org or not org.brain then return "" end
    local kleinerAudiblePain = {
        "Oh dear, that smarts!",
        "Fiddlesticks, that hurts!",
        "My word, the discomfort!",
        "Great Scott, the pain!",
        "This is most unpleasant.",
        "I wish I had some analgesics."
    }
    local kleinerBrokenLimb = {
        "Oh dear, I believe it's fractured.",
        "Fiddlesticks, a break.",
        "That's certainly not supposed to bend that way.",
    }
    local kleinerDislocatedLimb = {
        "Out of alignment, how bothersome.",
        "A dislocation, I must be careful.",
        "This joint is not where it belongs.",
        "I mustn't jostle it further.",
    }
    local kleinerHungry = {
        "I could do with a spot of lunch.",
        "A sandwich would be most welcome.",
        "My stomach is making its emptiness known.",
        "I should find sustenance soon.",
    }
    local kleinerVeryHungry = {
        "I am quite famished.",
        "My energy is waning without nourishment.",
        "I really must eat something.",
        "This hunger is becoming distracting.",
    }
    local kleinerCold = {
        "It's rather chilly in here.",
        "I could use a warmer coat.",
        "My teeth are chattering.",
        "The temperature is quite low.",
    }
    local kleinerFreezing = {
        "I... I can barely feel my extremities.",
        "It's frightfully cold.",
        "Hypothermia is a genuine concern.",
        "I must find warmth quickly.",
    }
    local kleinerFear = {
        "This is somewhat alarming.",
        "I do wish this wasn't happening.",
        "Steady on, Isaac.",
        "Remain calm, old boy.",
        "Focus on the science, not the fear.",
    }
    local kleinerAfterUnconscious = {
        "What happened? Oh, my head...",
        "I was out for a moment, wasn't I?",
        "Good heavens, that was unpleasant.",
        "I seem to have lost consciousness.",
        "Back to reality, I suppose.",
    }
    local kleinerBloodloss = {
        "I'm losing rather a lot of blood.",
        "This bleeding is concerning.",
        "I must apply pressure.",
        "My vision is swimming a bit.",
    }
    local kleinerBrainDamage = {
        "My thoughts are... muddled.",
        "Focus, Isaac. Focus.",
        "I'm having trouble concentrating.",
        "Something isn't quite right upstairs.",
    }
    local kleinerslightBrainDamage = {
        "Hmm?",
        "What was I doing?",
        "Pardon?",
        "I seem to have lost my train of thought.",
    }
    local old_get_status = hg.get_status_message
    function hg.get_status_message(ply)
        if not IsValid(ply) or ply.PlayerClassName ~= "drkleiner" then
            return old_get_status(ply)
        end
        local org = ply.organism
        if not org or not org.brain then return "" end
        local pain = org.pain or 0
        local brain = org.brain or 0
        local blood = org.blood or 5000
        local temperature = org.temperature or 36.7
        local hungry = org.hungry or 0
        local after_unconscious = org.after_otrub
        local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone + 3 - CurTime()) < -3)
        local broken_notify = (org.rarm == 1) or (org.larm == 1) or (org.rleg == 1) or (org.lleg == 1)
        local dislocated_notify = (org.rarm == 0.5) or (org.larm == 0.5) or (org.rleg == 0.5) or (org.lleg == 0.5)
        if pain > 75 then
            return table.Random(kleinerAudiblePain)
        end
        if broken_dislocated then
            if broken_notify then
                return table.Random(kleinerBrokenLimb)
            elseif dislocated_notify then
                return table.Random(kleinerDislocatedLimb)
            end
        end
        if brain > 0.1 then
            return table.Random(brain < 0.2 and kleinerslightBrainDamage or kleinerBrainDamage)
        end
        if blood < 3100 then
            return table.Random(kleinerBloodloss)
        end
        if temperature < 35 then
            return table.Random(temperature < 28 and kleinerFreezing or kleinerCold)
        end
        if hungry > 25 then
            return table.Random(hungry > 45 and kleinerVeryHungry or kleinerHungry)
        end
        if after_unconscious then
            return table.Random(kleinerAfterUnconscious)
        end
        if hg.fearful and hg.fearful(ply) then
            return table.Random(kleinerFear)
        end
        local defaultMsg = old_get_status(ply)
        return KleinerCleanText(defaultMsg)
    end
    local plymeta = FindMetaTable("Player")
    local old_Notify = plymeta.Notify
    function plymeta:Notify(msg, delay, msgKey, ...)
        if self.PlayerClassName == "drkleiner" then
            -- If it's a bone break/dislocation notification, use custom Kleiner message
            if msgKey and string.find(msgKey, "^broke") or string.find(msgKey, "^dislocated") then
                local customMsg = GetKleinerBoneMsg(msgKey)
                if customMsg then
                    msg = customMsg
                else
                    -- Fallback: clean the original message
                    msg = KleinerCleanText(msg)
                end
            else
                -- For all other notifications, just clean swears
                msg = KleinerCleanText(msg)
            end
        end
        return old_Notify(self, msg, delay, msgKey, ...)
    end
end
end
function CLASS.Off(self)
    if CLIENT then return end
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
end
function CLASS.On(self, data)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AClothes = ""
    self:SetNetVar("Accessories", "")
    self:SetSubMaterial()
    self.CurAppearance = Appearance
    self:SetNWString("PlayerName","Dr. Isaac Kleiner")
    self:SetPlayerColor(Color(255,255,255):ToVector())
    self:SetModel("models/player/kleiner.mdl")
    self.VoicePitch = 100
end
hook.Add("HG_ReplacePhrase", "KleinerPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "drkleiner" then return end
    local org = ply.organism
    local inpainscream = org and org.pain > 60 and org.pain < 100
    local inpain = org and org.pain > 100
    local new_phrase
    if inpainscream or inpain then
        new_phrase = table.Random(pain_lines)
    else
        new_phrase = table.Random(random_lines)
    end
    ply._nextSound = inpain and (inpainscream and table.Random(pain_lines)) or table.Random(random_lines)
    return ent, new_phrase, muffed, pitch
end)
return CLASS