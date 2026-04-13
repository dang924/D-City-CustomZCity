-- Superadmin Nuggify command.
-- Adds a superadmin-only player punish action that amputates and lobotomizes a target.

if CLIENT then return end

util.AddNetworkString("DCityPatch_Nuggify")

net.Receive("DCityPatch_Nuggify", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:IsSuperAdmin() then return end

    local entIndex = net.ReadUInt(16)
    local target = Entity(entIndex)
    if not IsValid(target) or not target:IsPlayer() then
        ply:ChatPrint("[DCityPatch] Invalid target.")
        return
    end
    if target:IsBot() then
        ply:ChatPrint("[DCityPatch] Cannot mutilate bots.")
        return
    end
    if not target:Alive() then
        ply:ChatPrint("[DCityPatch] Target must be alive.")
        return
    end
    if not target.organism then
        ply:ChatPrint("[DCityPatch] Target organism state unavailable.")
        return
    end

    local org = target.organism
    org.llegamputated = true
    org.rlegamputated = true
    org.larmamputated = true
    org.rarmamputated = true
    org.brain = 0.25
    org.consciousness = 0.25
    org.blood = math.max(org.blood or 3000, 3000)
    org.bleed = 0
    org.shock = 0
    org.otrub = false
    org.needotrub = false
    org.critical = false
    org.incapacitated = false
    org.alive = true

    if target:Health() < 20 then
        target:SetHealth(20)
    end

    if hg and hg.send_organism then
        hg.send_organism(org, target)
    end

    ply:ChatPrint("[DCityPatch] " .. target:Nick() .. " has been Nuggified.")
    target:ChatPrint("[DCityPatch] A superadmin has Nuggified you.")
end)
