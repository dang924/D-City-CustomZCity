-- sv_rally_point_admin.lua
-- Server-side spawn gate for ent_rally_point.
-- The entity sets AdminSpawnable = true (hidden from non-admin spawn tabs),
-- but this hook is the authoritative enforcement layer.

if CLIENT then return end

hook.Add("PlayerSpawnSENT", "ZC_RallyPointSpawnGate", function(ply, className)
    if className ~= "ent_rally_point" then return end
    if not IsValid(ply) then return false end
    if not ply:IsAdmin() then
        ply:ChatPrint("[Rally Point] Admins only.")
        return false
    end
end)
