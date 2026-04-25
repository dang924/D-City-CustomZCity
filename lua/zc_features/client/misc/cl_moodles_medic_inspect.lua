if SERVER then return end

local cv_enabled = CreateClientConVar("dcity_moodles_inspect_enabled", "1", true, false)
local cv_dist = CreateClientConVar("dcity_moodles_inspect_dist", "220", true, false)
local cv_max_icons = CreateClientConVar("dcity_moodles_inspect_max_icons", "7", true, false)
local cv_roles = CreateClientConVar("dcity_moodles_inspect_roles", "medic,doctor,ems,corpsman,surgeon", true, false)

local ICONS = {
    pain = Material("vgui/hud/status_pain_icon.png", "smooth"),
    bleeding = Material("vgui/hud/status_bleeding_icon.png", "smooth"),
    internal_bleed = Material("vgui/hud/status_internal_bleed_icon.png", "smooth"),
    conscious = Material("vgui/hud/status_conscious_icon.png", "smooth"),
    stamina = Material("vgui/hud/status_stamina_icon.png", "smooth"),
    spine_fracture = Material("vgui/hud/status_spine_fracture.png", "smooth"),
    fracture = Material("vgui/hud/status_leg_fracture.png", "smooth"),
    organ_damage = Material("vgui/hud/status_organ_damage.png", "smooth"),
    dislocation = Material("vgui/hud/status_dislocation.png", "smooth"),
    blood_loss = Material("vgui/hud/status_blood_loss.png", "smooth"),
    cardiac_arrest = Material("vgui/hud/status_cardiac_arrest.png", "smooth"),
    cold = Material("vgui/hud/status_cold.png", "smooth"),
    heat = Material("vgui/hud/status_heat.png", "smooth"),
    hemothorax = Material("vgui/hud/status_hemothorax.png", "smooth"),
    lungs_failure = Material("vgui/hud/status_lungs_failure.png", "smooth"),
    overdose = Material("vgui/hud/status_overdose.png", "smooth"),
    oxygen = Material("vgui/hud/status_oxygen.png", "smooth"),
    vomit = Material("vgui/hud/status_vomit.png", "smooth"),
    brain_damage = Material("vgui/hud/status_brain_damage.png", "smooth"),
    adrenaline = Material("vgui/hud/status_adrenaline.png", "smooth"),
    shock = Material("vgui/hud/status_shock.png", "smooth"),
    trauma = Material("vgui/hud/status_trauma.png", "smooth"),
    death = Material("vgui/hud/status_death.png", "smooth"),
    berserk = Material("vgui/hud/status_berserk.png", "smooth"),
    amputant = Material("vgui/hud/status_amputant.png", "smooth")
}

local BG_ICON = Material("vgui/hud/status_background.png", "smooth")
local BG_LEVEL = {
    [1] = Material("vgui/hud/status_level1_bg.png", "smooth"),
    [2] = Material("vgui/hud/status_level2_bg.png", "smooth"),
    [3] = Material("vgui/hud/status_level3_bg.png", "smooth"),
    [4] = Material("vgui/hud/status_level4_bg.png", "smooth")
}

local function getOrgVal(org, key, def)
    local v = org and org[key]
    if type(v) == "number" then return v end
    return def or 0
end

local function getOrgTableVal(org, tbl, key, index, def)
    local t = org and org[tbl]
    if type(t) ~= "table" then return def or 0 end
    local v = t[key]
    if index and type(v) == "table" then
        v = v[index]
    end
    if type(v) == "number" then return v end
    return def or 0
end

local function getO2Value(org)
    if not org or org.o2 == nil then return 30 end
    if type(org.o2) == "table" then return org.o2[1] or 30 end
    if type(org.o2) == "number" then return org.o2 end
    return 30
end

local function isDead(ply)
    if not IsValid(ply) then return true end
    if not ply:Alive() then return true end
    local org = ply.organism
    if org and org.alive == false then return true end
    return false
end

local function hasAnyFracture(org, threshold)
    threshold = threshold or 0.95
    return (getOrgVal(org, "lleg", 0) >= threshold and not org.llegamputated)
        or (getOrgVal(org, "rleg", 0) >= threshold and not org.rlegamputated)
        or (getOrgVal(org, "larm", 0) >= threshold and not org.larmamputated)
        or (getOrgVal(org, "rarm", 0) >= threshold and not org.rarmamputated)
end

local function hasAnyAmputation(org)
    return org.llegamputated == true
        or org.rlegamputated == true
        or org.larmamputated == true
        or org.rarmamputated == true
end

local function splitCSVLower(str)
    local out = {}
    if type(str) ~= "string" then return out end
    for part in string.gmatch(string.lower(str), "[^,]+") do
        local trimmed = string.Trim(part)
        if trimmed ~= "" then
            table.insert(out, trimmed)
        end
    end
    return out
end

local function isMedicInspector(ply)
    if not IsValid(ply) then return false end

    -- Mirror existing revive detection logic used by your coop/bleedout flow.
    if ply.PlayerClassName == "Gordon" then return true end
    if ply.subClass == "medic" then return true end

    -- Optional fallback for servers that expose role only via strings.
    local teamName = ""
    if team and team.GetName then
        teamName = team.GetName(ply:Team()) or ""
    end

    local jobName = ""
    if ply.getJobTable then
        local jt = ply:getJobTable()
        if jt and jt.name then
            jobName = tostring(jt.name)
        end
    end

    local nwJob = ""
    local nwRole = ""
    if ply.GetNWString then
        nwJob = ply:GetNWString("job", "")
        nwRole = ply:GetNWString("PlayerRole", "")
    end

    local roleText = string.lower(teamName .. " " .. jobName .. " " .. nwJob .. " " .. nwRole)
    for _, key in ipairs(splitCSVLower(cv_roles:GetString())) do
        if string.find(roleText, key, 1, true) then
            return true
        end
    end

    return false
end

local function isHiddenRoundActive()
    local round = CurrentRound and CurrentRound()
    return round and round.name == "hidden"
end

local function getInspectTarget()
    if isHiddenRoundActive() then return nil end

    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return nil end
    if not lp.organism or lp.organism.otrub then return nil end

    local dist = math.max(80, cv_dist:GetInt())

    -- Use standard GetEyeTrace for full range (hits both standing players and props).
    -- hg.eyeTrace traces only 60 units by default, so it misses standing players.
    -- Then resolve fake ragdoll props back to the owning player entity.
    local tr = lp:GetEyeTrace()
    local ent = tr and tr.Entity
    if IsValid(ent) and not ent:IsPlayer() and ent.ply then
        ent = ent.ply
    end

    if IsValid(ent) and ent:IsPlayer() and ent ~= lp and ent.organism then
        if ent:GetPos():Distance(lp:GetPos()) <= dist then
            return ent
        end
    end

    return nil
end

local function addLevelEffect(effects, name, value, thresholds, prio)
    local lvl = 1
    if value <= thresholds[1] then lvl = 4
    elseif value <= thresholds[2] then lvl = 3
    elseif value <= thresholds[3] then lvl = 2 end
    effects[#effects + 1] = {name = name, level = lvl, prio = prio}
end

local function buildEffects(org, target)
    local effects = {}

    if isDead(target) then
        effects[#effects + 1] = {name = "death", level = 4, prio = -1000}
        return effects
    end

    local berserkActive = org.berserkActive2 == true

    local pain = getOrgVal(org, "pain", 0)
    if pain > 10 and not berserkActive then
        local lvl = 1
        if pain >= 60 then lvl = 4 elseif pain >= 40 then lvl = 3 elseif pain >= 25 then lvl = 2 end
        effects[#effects + 1] = {name = "pain", level = lvl, prio = 0}
    end

    if berserkActive then
        local b = getOrgVal(org, "berserk", 0)
        local lvl = 1
        if b > 2.5 then lvl = 4 elseif b > 1.5 then lvl = 3 elseif b > 0.5 then lvl = 2 end
        effects[#effects + 1] = {name = "berserk", level = lvl, prio = -1}
    end

    if getOrgVal(org, "bleed", 0) > 0.1 then effects[#effects + 1] = {name = "bleeding", prio = 0.3} end
    if getOrgVal(org, "internalBleed", 0) > 0.1 then effects[#effects + 1] = {name = "internal_bleed", prio = 0.4} end

    local cons = math.floor(getOrgVal(org, "consciousness", 1) * 100)
    if cons < 90 then addLevelEffect(effects, "conscious", cons, {24, 49, 74}, 1) end

    if type(org.stamina) == "table" then
        local stMax = org.stamina.max or 180
        if stMax <= 0 then stMax = 180 end
        local stPct = (org.stamina[1] or 0) / stMax * 100
        if stPct < 75 then addLevelEffect(effects, "stamina", stPct, {24, 49, 74}, 2) end
    end

    local s1, s2, s3 = getOrgVal(org, "spine1", 0), getOrgVal(org, "spine2", 0), getOrgVal(org, "spine3", 0)
    if s1 >= 0.95 or s2 >= 0.95 or s3 >= 0.95 then effects[#effects + 1] = {name = "spine_fracture", prio = 3} end
    if hasAnyFracture(org, 0.95) then effects[#effects + 1] = {name = "fracture", prio = 6} end

    local organDamage = math.max(
        getOrgVal(org, "heart", 0),
        getOrgVal(org, "liver", 0),
        getOrgVal(org, "stomach", 0),
        getOrgVal(org, "intestines", 0),
        getOrgTableVal(org, "lungsR", 1, nil, 0),
        getOrgTableVal(org, "lungsL", 1, nil, 0),
        getOrgTableVal(org, "lungsR", 2, nil, 0),
        getOrgTableVal(org, "lungsL", 2, nil, 0)
    )
    if organDamage > 0.3 then effects[#effects + 1] = {name = "organ_damage", prio = 4} end

    if org.llegdislocation or org.rlegdislocation or org.larmdislocation or org.rarmdislocation or org.jawdislocation then
        effects[#effects + 1] = {name = "dislocation", prio = 5}
    end

    local blood = getOrgVal(org, "blood", 5000)
    if blood < 4700 then addLevelEffect(effects, "blood_loss", blood, {2500, 3600, 4500}, 0.1) end

    if org.heartstop == true then effects[#effects + 1] = {name = "cardiac_arrest", prio = 0.15} end

    local temp = getOrgVal(org, "temperature", 36.7)
    if temp < 36 then addLevelEffect(effects, "cold", temp, {31, 33, 35}, 0.2) end
    if temp > 37 then
        local lvl = 1
        if temp > 40 then lvl = 4 elseif temp > 39 then lvl = 3 elseif temp > 38 then lvl = 2 end
        effects[#effects + 1] = {name = "heat", level = lvl, prio = 0.2}
    end

    local pneumo = getOrgVal(org, "pneumothorax", 0)
    if pneumo > 0.01 then
        local lvl = 1
        if pneumo > 0.7 then lvl = 4 elseif pneumo > 0.3 then lvl = 3 elseif pneumo > 0.1 then lvl = 2 end
        effects[#effects + 1] = {name = "hemothorax", level = lvl, prio = 0.25}
    end

    if org.lungsfunction == false then effects[#effects + 1] = {name = "lungs_failure", prio = 0.35} end

    local analgesia = getOrgVal(org, "analgesia", 0)
    if analgesia > 0.1 then
        local lvl = 1
        if analgesia > 2 then lvl = 4 elseif analgesia > 1.6 then lvl = 3 elseif analgesia > 1 then lvl = 2 end
        effects[#effects + 1] = {name = "overdose", level = lvl, prio = 0.45}
    end

    local o2 = getO2Value(org)
    if o2 < 28 then addLevelEffect(effects, "oxygen", o2, {8, 14, 23}, 0.5) end

    local vomit = getOrgVal(org, "wantToVomit", 0)
    if vomit > 0.2 then
        local lvl = 1
        if vomit > 0.9 then lvl = 4 elseif vomit > 0.8 then lvl = 3 elseif vomit > 0.6 then lvl = 2 end
        effects[#effects + 1] = {name = "vomit", level = lvl, prio = 0.55}
    end

    local brain = getOrgVal(org, "brain", 0)
    if brain > 0.01 then
        local lvl = 1
        if brain > 0.3 then lvl = 4 elseif brain > 0.25 then lvl = 3 elseif brain > 0.15 then lvl = 2 end
        effects[#effects + 1] = {name = "brain_damage", level = lvl, prio = 0.6}
    end

    local adrenaline = getOrgVal(org, "adrenaline", 0)
    if adrenaline > 0.3 then
        local lvl = 1
        if adrenaline > 2.1 then lvl = 4 elseif adrenaline > 1.5 then lvl = 3 elseif adrenaline > 0.8 then lvl = 2 end
        effects[#effects + 1] = {name = "adrenaline", level = lvl, prio = 0.65}
    end

    local shock = getOrgVal(org, "shock", 0)
    if shock > 20 then addLevelEffect(effects, "shock", shock, {35, 25, 10}, 0.7) end

    local trauma = getOrgVal(org, "disorientation", 0)
    if trauma > 0.2 then
        local lvl = 1
        if trauma > 3 then lvl = 4 elseif trauma > 2.5 then lvl = 3 elseif trauma > 1 then lvl = 2 end
        effects[#effects + 1] = {name = "trauma", level = lvl, prio = 0.75}
    end

    if hasAnyAmputation(org) then effects[#effects + 1] = {name = "amputant", prio = 8} end

    table.sort(effects, function(a, b)
        return (a.prio or 0) < (b.prio or 0)
    end)

    return effects
end

local function drawEffectIcon(effect, x, y, size)
    local lvl = math.Clamp(tonumber(effect.level) or 1, 1, 4)
    local bg = BG_LEVEL[lvl] or BG_ICON
    if bg and not bg:IsError() then
        surface.SetDrawColor(255, 255, 255, 230)
        surface.SetMaterial(bg)
        surface.DrawTexturedRect(x, y, size, size)
    else
        surface.SetDrawColor(50, 60, 76, 230)
        surface.DrawRect(x, y, size, size)
    end

    local icon = ICONS[effect.name]
    if icon and not icon:IsError() then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(icon)
        surface.DrawTexturedRect(x + 2, y + 2, size - 4, size - 4)
    else
        local letter = string.upper(string.sub(effect.name or "?", 1, 1))
        draw.SimpleText(letter, "DermaDefaultBold", x + size * 0.5, y + size * 0.5, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

hook.Add("HUDPaint", "DCityPatch_MoodlesMedicInspect", function()
    if not cv_enabled:GetBool() then return end
    if isHiddenRoundActive() then return end

    local target = getInspectTarget()
    if not IsValid(target) then return end

    local screen = (target:EyePos() + Vector(0, 0, 8)):ToScreen()
    if not screen.visible then return end

    local effects = buildEffects(target.organism, target)
    local maxIcons = math.max(1, cv_max_icons:GetInt())
    local drawCount = math.min(#effects, maxIcons)

    local iconSize = 26
    local spacing = 30
    local headerH = 16
    local panelH = 46
    local panelW = math.max(190, drawCount * spacing + 24)

    local x = screen.x + 24
    local y = screen.y - 22

    draw.RoundedBox(6, x, y, panelW, panelH, Color(18, 22, 28, 210))
    draw.SimpleText(target:Nick(), "DermaDefaultBold", x + 8, y + 3, Color(220, 240, 255, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    if drawCount <= 0 then
        draw.SimpleText("Stable", "DermaDefault", x + 8, y + headerH + 10, Color(140, 230, 140, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        return
    end

    for i = 1, drawCount do
        drawEffectIcon(effects[i], x + 8 + (i - 1) * spacing, y + headerH + 2, iconSize)
    end

    if #effects > drawCount then
        draw.SimpleText("+" .. tostring(#effects - drawCount), "DermaDefault", x + panelW - 8, y + panelH - 6, Color(200, 210, 230, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end
end)

hook.Add("PopulateToolMenu", "DCityPatch_MoodlesMedicInspect_Menu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Zcity", "DCityPatch_MoodlesMedicInspect", "Moodles Medic Inspect", "", "", function(panel)
        panel:ClearControls()
        panel:CheckBox("Enable medic moodle inspect", "dcity_moodles_inspect_enabled")
        panel:NumSlider("Inspect distance", "dcity_moodles_inspect_dist", 80, 500, 0)
        panel:NumSlider("Max shown icons", "dcity_moodles_inspect_max_icons", 1, 14, 0)
        panel:TextEntry("Medic role keywords (comma separated)", "dcity_moodles_inspect_roles")
        panel:Help("Example roles: medic,doctor,ems,corpsman,surgeon")
    end)
end)
