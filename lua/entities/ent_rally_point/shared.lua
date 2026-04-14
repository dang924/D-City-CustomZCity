ENT.Type           = "anim"
ENT.Base           = "base_gmodentity"
ENT.PrintName      = "Rally Point"
ENT.Author         = "DCity"
ENT.Category       = "ZCity - Admin"
ENT.Spawnable      = true

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Active")
end

-- Right-click context menu toggle (physgun right-click or C-menu).
-- Filter + Action run CLIENT-side; Receive runs SERVER-side.
-- properties.Add is available on both realms in GMod.
properties.Add("rally_point_toggle", {
    MenuLabel = "Toggle Rally Point",
    Order     = 999,
    MenuIcon  = "icon16/door.png",

    Filter = function(self, ent, ply)
        return IsValid(ent)
            and ent:GetClass() == "ent_rally_point"
            and IsValid(ply)
            and ply:IsAdmin()
    end,

    Action = function(self, ent)
        self:MsgStart()
        net.WriteEntity(ent)
        self:MsgEnd()
    end,

    Receive = function(self, length, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) or ent:GetClass() ~= "ent_rally_point" then return end
        if not IsValid(ply) or not ply:IsAdmin() then return end
        ent:SetActiveState(not ent:GetActive())
        local state = ent:GetActive()
            and "ACTIVE - players who step here will rally all players"
            or  "INACTIVE (visible)"
        ply:ChatPrint("[Rally Point] " .. state)
    end,
})
