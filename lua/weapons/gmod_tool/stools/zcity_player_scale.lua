TOOL.Category = "ZCity"
TOOL.Name = "#tool.zcity_player_scale.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    height = "100",
    weight = "100"
}

TOOL.Information = {
    { name = "left" },
    { name = "right" },
    { name = "reload" }
}

local SELECTION_NW_KEY = "HG_ZCityPlayerScale_Target"
local SELECT_SELF_NET = "HG.ZCityPlayerScale.SelectSelf"

if CLIENT then
    language.Add("tool.zcity_player_scale.name", "ZCity Player Scale")
    language.Add("tool.zcity_player_scale.desc", "Temporarily changes a player's height and weight without saving to appearance presets")
    language.Add("tool.zcity_player_scale.left", "Apply current sliders to selected player")
    language.Add("tool.zcity_player_scale.right", "Select player under crosshair")
    language.Add("tool.zcity_player_scale.reload", "Select yourself")
    language.Add("tool.zcity_player_scale.height", "Height")
    language.Add("tool.zcity_player_scale.weight", "Weight")

    local haloColor = Color(220, 220, 255)
    hook.Add("PreDrawHalos", "HG.ZCityPlayerScaleHalo", function()
        local lply = LocalPlayer()
        if not IsValid(lply) then return end

        local weapon = lply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then return end

        local tool = lply.GetTool and lply:GetTool()
        if not tool or tool.Mode ~= "zcity_player_scale" then return end

        local ent = lply:GetNWEntity(SELECTION_NW_KEY)
        if not IsValid(ent) or not ent:IsPlayer() then return end

        halo.Add({ent}, haloColor, 2, 2, 1, true, true)
    end)
end

local function IsScaleTarget(ent)
    return IsValid(ent) and ent:IsPlayer()
end

local function SetSelectedTarget(ply, target)
    if not IsValid(ply) then return end
    ply:SetNWEntity(SELECTION_NW_KEY, IsScaleTarget(target) and target or NULL)
end

local function ToggleSelectedTarget(ply, target)
    if not IsValid(ply) then return false end
    if not IsScaleTarget(target) then
        SetSelectedTarget(ply, nil)
        return false
    end

    local current = ply:GetNWEntity(SELECTION_NW_KEY)
    if IsScaleTarget(current) and current == target then
        SetSelectedTarget(ply, nil)
        return false
    end

    SetSelectedTarget(ply, target)
    return true
end

local function GetSelectedTarget(ply)
    if not IsValid(ply) then return nil end

    local target = ply:GetNWEntity(SELECTION_NW_KEY)
    if IsScaleTarget(target) then
        return target
    end
end

if SERVER then
    util.AddNetworkString(SELECT_SELF_NET)

    net.Receive(SELECT_SELF_NET, function(_, ply)
        ToggleSelectedTarget(ply, ply)
    end)
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    if not IsScaleTarget(trace.Entity) then return false end

    ToggleSelectedTarget(self:GetOwner(), trace.Entity)
    return true
end

function TOOL:Reload()
    if CLIENT then
        net.Start(SELECT_SELF_NET)
        net.SendToServer()
        return true
    end

    return true
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local owner = self:GetOwner()
    local target = GetSelectedTarget(owner)
    if not IsScaleTarget(target) then
        target = IsScaleTarget(trace.Entity) and trace.Entity or nil
        if not IsScaleTarget(target) then return false end
        SetSelectedTarget(owner, target)
    end

    hg = hg or {}
    hg.Appearance = hg.Appearance or {}
    local appearance = hg.Appearance
    if not isfunction(appearance.ApplyTemporaryPlayerScale) then return false end

    appearance.ApplyTemporaryPlayerScale(
        target,
        self:GetClientNumber("height", 100),
        self:GetClientNumber("weight", 100)
    )

    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("#tool.zcity_player_scale.desc")
    panel:NumSlider("#tool.zcity_player_scale.height", "zcity_player_scale_height", 95, 110, 0)
    panel:NumSlider("#tool.zcity_player_scale.weight", "zcity_player_scale_weight", 95, 110, 0)
end
