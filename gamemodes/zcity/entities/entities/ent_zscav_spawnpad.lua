-- ZScav Spawn Pad.
-- Runtime pads are recreated from ZSCAV_PAD Point Editor points at round
-- start. The raid controller owns occupancy, countdown, and deployment.

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "ZScav Spawn Pad"
ENT.Author      = "ZScav"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.Category    = "ZCity"

local PAD_MODEL    = "models/hunter/tubes/circle2x2.mdl"
local PAD_RADIUS   = 96
local PAD_RADIUS_PADDING = 28
local PAD_Z_BELOW = 72
local PAD_Z_ABOVE = 144

ENT.ZScavPadRadius = PAD_RADIUS

local function isPointInsidePad(origin, point, radius)
    local dx, dy = point.x - origin.x, point.y - origin.y
    if (dx * dx + dy * dy) > (radius * radius) then
        return false
    end

    return point.z >= (origin.z - PAD_Z_BELOW) and point.z <= (origin.z + PAD_Z_ABOVE)
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(PAD_MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:DrawShadow(false)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        self:SetNWInt("ZScavPadCapacity", 2)
        self:SetNWInt("ZScavPadOccupants", 0)
        self:SetNWBool("ZScavPadArmed", false)
        self:SetNWBool("ZScavPadFull", false)
        self:SetNWFloat("ZScavPadCountdownEnd", 0)
    end

    function ENT:IsPlayerOnPad(ply)
        if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return false end

        local origin = self:GetPos()
        local radius = math.max(tonumber(self.ZScavPadRadius) or PAD_RADIUS, 32) + PAD_RADIUS_PADDING

        if isPointInsidePad(origin, ply:GetPos(), radius) then
            return true
        end

        return isPointInsidePad(origin, ply:WorldSpaceCenter(), radius)
    end

    function ENT:GetOccupants()
        local list = {}
        for _, ply in ipairs(player.GetAll()) do
            if self:IsPlayerOnPad(ply) then
                list[#list + 1] = ply
            end
        end
        return list
    end

    function ENT:Use(activator, _caller, _useType)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        if not activator:Alive() then return end

        local lateWindowEnd = GetGlobalFloat("ZScavRaidLateSpawnWindowEnd", 0)
        local lateCountdownEnd = GetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", 0)
        if lateWindowEnd > CurTime() or lateCountdownEnd > CurTime() then
            activator:ChatPrint("[ZScav] Stand on the pad to queue for the next late deployment.")
            return
        end

        activator:ChatPrint("[ZScav] Stand on the pad to queue for the next raid.")
    end
end

if CLIENT then
    local function formatSeconds(seconds)
        seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
        local minutes = math.floor(seconds / 60)
        local remain = seconds % 60
        return string.format("%02d:%02d", minutes, remain)
    end

    function ENT:Draw()
        self:DrawModel()

        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local dist = lp:GetPos():DistToSqr(self:GetPos())
        if dist > (256 * 256) then return end

        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang.p = 0
        ang.r = 90
        ang.y = EyeAngles().y - 90

        local pos = self:GetPos() + Vector(0, 0, 18)
        local armedAt = GetGlobalFloat("ZScavRaidPadsArmedAt", 0)
        local countdownEnd = math.max(GetGlobalFloat("ZScavRaidPadCountdownEnd", 0), self:GetNWFloat("ZScavPadCountdownEnd", 0))
        local battlefieldPlayers = GetGlobalInt("ZScavRaidBattlefieldPlayers", 0)
        local lateWindowEnd = GetGlobalFloat("ZScavRaidLateSpawnWindowEnd", 0)
        local lateCountdownEnd = GetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", 0)
        local lateReadyPlayers = GetGlobalInt("ZScavRaidLateSpawnReadyPlayers", 0)
        local occupants = self:GetNWInt("ZScavPadOccupants", 0)
        local capacity = math.max(self:GetNWInt("ZScavPadCapacity", 2), 1)
        local armed = self:GetNWBool("ZScavPadArmed", false)
        local full = self:GetNWBool("ZScavPadFull", false)

        local headline = "RAID PAD"
        local subline = string.format("%d/%d READY", occupants, capacity)
        local color = Color(120, 220, 255, 220)

        if lateCountdownEnd > CurTime() then
            headline = "LATE DEPLOY IN " .. formatSeconds(lateCountdownEnd - CurTime())
            subline = string.format("%d/%d READY ON THIS PAD  |  %d TOTAL QUEUED", occupants, capacity, lateReadyPlayers)
            color = Color(245, 188, 72, 230)
        elseif lateWindowEnd > CurTime() then
            headline = "LATE DEPLOYMENT OPEN"
            subline = string.format("WINDOW %s  |  %d TOTAL QUEUED", formatSeconds(lateWindowEnd - CurTime()), lateReadyPlayers)
            color = Color(112, 210, 140, 230)
        elseif battlefieldPlayers > 0 then
            headline = "RAID IN PROGRESS"
            subline = string.format("%d PLAYER%s STILL OUTSIDE SAFE ZONE", battlefieldPlayers, battlefieldPlayers == 1 and "" or "S")
            color = Color(245, 120, 120, 230)
        elseif armedAt > CurTime() then
            headline = "PADS ARM IN " .. formatSeconds(armedAt - CurTime())
            subline = "Wait for the staging timer"
        elseif countdownEnd > CurTime() then
            headline = "LAUNCH IN " .. formatSeconds(countdownEnd - CurTime())
            subline = string.format("%d/%d READY ON THIS PAD", occupants, capacity)
            color = Color(245, 188, 72, 230)
        elseif armed and full then
            headline = "PAD FULL"
            subline = "Leave to free a slot"
            color = Color(245, 120, 120, 220)
        elseif armed then
            headline = string.format("%d/%d READY", occupants, capacity)
            subline = "Stand here to queue"
        end

        cam.Start3D2D(pos, ang, 0.18)
            local pulse = (math.sin(CurTime() * 3) + 1) * 0.5
            local alpha = 180 + math.floor(60 * pulse)
            draw.RoundedBox(8, -180, -34, 360, 68, Color(20, 22, 28, alpha))
            draw.SimpleText(headline, "DermaLarge", 0, -10, Color(color.r, color.g, color.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(subline, "DermaDefaultBold", 0, 14, Color(235, 235, 235, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    hook.Add("PostDrawTranslucentRenderables", "ZScav_SpawnPadHalo", function(_d, sky, sky3d)
        if sky or sky3d then return end
        for _, ent in ipairs(ents.FindByClass("ent_zscav_spawnpad")) do
            if not IsValid(ent) then continue end

            local center = ent:GetPos() + Vector(0, 0, 1)
            local pulse  = (math.sin(CurTime() * 2) + 1) * 0.5
            local alpha  = math.floor(50 + 60 * pulse)
            local drawColor = Color(120, 220, 255, alpha)

            if GetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", 0) > CurTime() then
                drawColor = Color(245, 188, 72, alpha)
            elseif GetGlobalFloat("ZScavRaidLateSpawnWindowEnd", 0) > CurTime() then
                drawColor = Color(112, 210, 140, alpha)
            elseif ent:GetNWFloat("ZScavPadCountdownEnd", 0) > CurTime() or GetGlobalFloat("ZScavRaidPadCountdownEnd", 0) > CurTime() then
                drawColor = Color(245, 188, 72, alpha)
            elseif ent:GetNWBool("ZScavPadFull", false) then
                drawColor = Color(245, 120, 120, alpha)
            end

            cam.Start3D2D(center, Angle(0, 0, 0), 1)
                surface.SetDrawColor(drawColor)
                local segs, r = 48, 96
                for i = 0, segs - 1 do
                    local a1 = (i       / segs) * math.pi * 2
                    local a2 = ((i + 1) / segs) * math.pi * 2
                    surface.DrawLine(
                        math.cos(a1) * r, math.sin(a1) * r,
                        math.cos(a2) * r, math.sin(a2) * r
                    )
                end
                surface.SetDrawColor(drawColor.r, drawColor.g, drawColor.b, math.floor(alpha * 0.25))
                for i = 0, segs - 1 do
                    local a1 = (i       / segs) * math.pi * 2
                    local a2 = ((i + 1) / segs) * math.pi * 2
                    local rr = r - 4
                    surface.DrawLine(
                        math.cos(a1) * rr, math.sin(a1) * rr,
                        math.cos(a2) * rr, math.sin(a2) * rr
                    )
                end
            cam.End3D2D()
        end
    end)
end
