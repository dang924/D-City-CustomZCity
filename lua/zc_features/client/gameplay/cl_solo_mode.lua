-- Client-side solo mode: enables the spawn menu when solo by removing
-- ZCity's SpawnMenuWhitelist hook, and restores it when a second player joins.

if SERVER then return end

local soloMode = false

local function EnableSpawnMenu()
    hook.Remove("SpawnMenuOpen", "SpawnMenuWhitelist")
end

local function DisableSpawnMenu()
    -- Re-add ZCity's original hook
    hook.Add("SpawnMenuOpen", "SpawnMenuWhitelist", function()
        local ply = LocalPlayer()
        if ply:IsSuperAdmin() then return end
        if ply:IsAdmin() then return end
        return false
    end)
end

net.Receive("ZC_SoloMode", function()
    soloMode = net.ReadBool()
    if soloMode then
        EnableSpawnMenu()
        LocalPlayer():ChatPrint("[ZCity] Solo mode — spawn menu enabled (F1).")
    else
        DisableSpawnMenu()
        LocalPlayer():ChatPrint("[ZCity] Another player joined — spawn menu disabled.")
    end
end)
