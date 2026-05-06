if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool
local NET = TOOLMODULE.Net

TOOLMODULE.ClientConfig = TOOLMODULE.ClientConfig or TOOLMODULE.GetDefaultAppearance()

net.Receive(NET.SyncConfig, function()
    local appearance = net.ReadTable()
    TOOLMODULE.ClientConfig = TOOLMODULE.NormalizeAppearance(appearance)
end)

local previousGetClientConfig = TOOLMODULE.GetClientConfig
function TOOLMODULE.GetClientConfig()
    TOOLMODULE.ClientConfig = TOOLMODULE.NormalizeAppearance(TOOLMODULE.ClientConfig or TOOLMODULE.GetDefaultAppearance())
    return TOOLMODULE.ClientConfig
end

local previousSetClientConfig = TOOLMODULE.SetClientConfig
function TOOLMODULE.SetClientConfig(tbl)
    tbl = TOOLMODULE.NormalizeAppearance(tbl)
    TOOLMODULE.ClientConfig = table.Copy(tbl)

    net.Start(NET.SaveConfig)
        net.WriteTable(TOOLMODULE.ClientConfig)
    net.SendToServer()
end

local previousRequestConfigSync = TOOLMODULE.RequestConfigSync
function TOOLMODULE.RequestConfigSync()
    net.Start(NET.RequestConfig)
    net.SendToServer()
end

local haloColor = Color(220, 220, 255)
hook.Add("PreDrawHalos", "HG.ZCAT.SelectedTargetHalo", function()
    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    local weapon = lply:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= "gmod_tool" then return end

    local tool = lply.GetTool and lply:GetTool()
    if not tool or tool.Mode ~= TOOLMODULE.ModeTag then return end

    local ent = lply:GetNWEntity(TOOLMODULE.SelectionNWKey)
    if not TOOLMODULE.IsSupportedTarget(ent) then return end

    halo.Add({ent}, haloColor, 2, 2, 1, true, true)
end)

hook.Add("InitPostEntity", "HG.ZCAT.RequestInitialConfig", function()
    timer.Simple(1, function()
        if not IsValid(LocalPlayer()) then return end
        TOOLMODULE.RequestConfigSync()
    end)
end)

hook.Add("InitPostEntity", "HG.ZCAT.SafePointshopCompatibility", function()
    local plyMeta = FindMetaTable("Player")
    if not plyMeta or plyMeta.__ZCATSafePSHasItemPatched then return end

    plyMeta.__ZCATSafePSHasItemPatched = true
    local previous = plyMeta.PS_HasItem

    function plyMeta:PS_HasItem(uid)
        local pointshopVars = LocalPlayer() and LocalPlayer().PS_MyItensens
        if not istable(pointshopVars) or not istable(pointshopVars.items) then
            return false
        end

        if previous then
            local ok, result = pcall(previous, self, uid)
            if ok then
                return result
            end
        end

        return pointshopVars.items[uid] or false
    end

    if hg.PointShop and hg.PointShop.SendNET then
        hg.PointShop:SendNET("SendPointShopVars")
    end
end)
