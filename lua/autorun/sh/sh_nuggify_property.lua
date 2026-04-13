if _G.DCityPatch_NuggifyPropertyLoaded then return end
_G.DCityPatch_NuggifyPropertyLoaded = true

if SERVER then
    util.AddNetworkString("DCityPatch_Nuggify")
end

local function CanNuggify(self, ent, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:IsSuperAdmin() then return false end
    if not ply:ZCTools_GetAccess() then return false end
    if not IsValid(ent) then return false end

    if ent:IsPlayer() then
        return ent:Alive()
    end

    if not hg or not hg.RagdollOwner then return false end
    local pEnt = hg.RagdollOwner(ent)
    return ent:IsRagdoll() and IsValid(pEnt) and pEnt:IsPlayer() and pEnt:Alive()
end

local function NuggifyTarget(ent)
    if not IsValid(ent) or not ent:IsPlayer() or not ent:Alive() then return false end
    if not ent.organism then return false end

    local org = ent.organism
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

    if ent:Health() < 20 then
        ent:SetHealth(20)
    end

    if hg and hg.send_organism then
        hg.send_organism(org, ent)
    end

    return true
end

local function RegisterNuggifyProperty()
    if not properties or not properties.Add then return false end

    properties.Add("nuggify", {
        MenuLabel = "Nuggify",
        Order = 13.5,
        MenuIcon = "icon16/heart.png",

        Filter = CanNuggify,

        Action = function(self, ent)
            if not IsValid(ent) then return end

            Derma_Query(
                "Nuggify this player?",
                "Confirm Nuggify",
                "Yes",
                function()
                    self:MsgStart()
                        net.WriteEntity(ent)
                    self:MsgEnd()
                end,
                "No"
            )
        end,

        Receive = function(self, length, ply)
            local ent = net.ReadEntity()
            if not self:Filter(ent, ply) then return end
            ent = hg.RagdollOwner(ent) or ent
            if not IsValid(ent) or not ent:IsPlayer() or not ent:Alive() then return end

            if not NuggifyTarget(ent) then return end

            ply:ChatPrint("[DCityPatch] " .. ent:Nick() .. " has been Nuggified.")
            ent:ChatPrint("[DCityPatch] A superadmin has Nuggified you.")
        end,
    })

    return true
end

local function TryRegisterNuggifyProperty()
    if RegisterNuggifyProperty() then
        hook.Remove("InitPostEntity", "DCityPatch_NuggifyPropertyInit")
        timer.Remove("DCityPatch_NuggifyPropertyRegister")
    end
end

hook.Add("InitPostEntity", "DCityPatch_NuggifyPropertyInit", TryRegisterNuggifyProperty)
timer.Create("DCityPatch_NuggifyPropertyRegister", 1, 10, TryRegisterNuggifyProperty)
TryRegisterNuggifyProperty()
