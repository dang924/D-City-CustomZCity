-- sv_coop_organism_npcs_toggle.lua
-- Exposes hg_noorganismnpcs in the coop loadout menu for superadmins.

if CLIENT then return end

util.AddNetworkString("ZC_RequestNoOrganismNPCs")
util.AddNetworkString("ZC_SendNoOrganismNPCs")
util.AddNetworkString("ZC_SaveNoOrganismNPCs")

local function getNoOrganismValue()
    local cv = GetConVar("hg_noorganismnpcs")
    if not cv then return false end
    return cv:GetBool()
end

local function sendNoOrganismValue(ply)
    if not IsValid(ply) then return end
    net.Start("ZC_SendNoOrganismNPCs")
    net.WriteBool(getNoOrganismValue())
    net.Send(ply)
end

net.Receive("ZC_RequestNoOrganismNPCs", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    sendNoOrganismValue(ply)
end)

net.Receive("ZC_SaveNoOrganismNPCs", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local desired = net.ReadBool() and "1" or "0"
    RunConsoleCommand("hg_noorganismnpcs", desired)

    sendNoOrganismValue(ply)
end)
