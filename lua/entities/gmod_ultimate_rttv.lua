AddCSLuaFile()

ENT.Base = WireLib and "base_wire_entity" or "base_gmodentity"

local cam = cam
local render = render
local surface = surface
local CurTime = CurTime
local IsValid = IsValid

ENT.PrintName = "Ultimate RT Monitor"
ENT.Type = "anim"
ENT.Spawnable = false

ENT.IsUltimateRTTV = true

if SERVER then
    ENT.IDMode = 0
    ENT.ContraptionID = 0

    function ENT:SetIDMode( mode )
        self.IDMode = urtcam.NormalizeIDMode and urtcam.NormalizeIDMode(mode) or mode
    end

    function ENT:GetIDMode()
        return self.IDMode
    end
end

function ENT:SetupDataTables()
    self:NetworkVar( "Entity", "Player" )
    self:NetworkVar( "String", "ID" )
    self:NetworkVar( "String", "ActualID" )
    self:NetworkVar( "Bool", "ShowID" )
    self:NetworkVar( "String", "ScreenFX" )
end

if SERVER then
    local rrtvCount = 0

    hook.Add( "SetupPlayerVisibility", "UltimateRTCam:SetupPlayerVisibility", function( ply, viewEntity )
        if rrtvCount <= 0 then return end
        local cvPVS = urtcam and urtcam.cvPVS
        if cvPVS and not cvPVS:GetBool() then return end

        local nextCheck = ply.urtcamNextPVSCheck or 0
        if CurTime() < nextCheck then return end

        local plyPos = ply:EyePos()
        local closestDistanceSqr = math.huge
        local curTV = nil

        for _, ent in pairs( ents.FindInSphere( plyPos, 512 ) ) do
            if ent.IsUltimateRTTV and IsValid( urtcam.CamByID[ ent:GetID() ] ) then
                local distSqr = plyPos:DistToSqr( ent:GetPos() )
                if distSqr < closestDistanceSqr then
                    curTV = ent
                    closestDistanceSqr = distSqr
                end
            end
        end

        if curTV then
            if not ply:TestPVS( curTV:GetPos() ) then -- tv is never gonna get rendered here!
                ply.urtcamNextPVSCheck = CurTime() + math.Rand( 1, 2 )
                return
            end
            ply.urtcamNextPVSCheck = 0
            local camera = urtcam.CamByID[ curTV:GetID() ]
            local pos = camera:GetPos()
            if ply:TestPVS( pos ) then return end -- this doesn't work well for some reason and returns true when it's clearly not in PVS
            AddOriginToPVS( pos )
        else
            ply.urtcamNextPVSCheck = CurTime() + math.Rand( 1, 2 )
        end
    end )
    function ENT:Initialize()
        rrtvCount = rrtvCount + 1
        self:CallOnRemove( "rrtv_decrement_count", function()
            rrtvCount = rrtvCount - 1
        end )

        self:SetUseType( SIMPLE_USE )

        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetSolid( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )

        if !WireLib then return end
        WireLib.CreateSpecialInputs( self, { "Camera", "CameraID", "IDMode" }, { "ENTITY", "STRING", "NORMAL" }, { "", "", "0 = Global/Public; 1 = Legacy Private alias to Global/Public; 2 = Local" } )
    end

    function ENT:TriggerInput( name, value )
        if name == "Camera" then
            local ent = value

            if not IsValid( ent ) or ent:GetClass() != "gmod_ultimate_rtcam" then
                local idMode = self.Inputs.IDMode.Value
                self:SetIDMode( idMode )

                local id = urtcam.GetIDByMode( self:GetActualID(), self:GetIDMode(), self:GetPlayer() )

                self:SetID( id )
                return
            end

            local entIndex = ent:EntIndex()

            self:SetIDMode( urtcam.ID_MODE_WIRE )
            ent:SetIDMode( urtcam.ID_MODE_WIRE )

            self:SetID( "W_" .. entIndex )
            ent:SetID( "W_" .. entIndex )
        elseif name == "CameraID" then
            if self:GetIDMode() == urtcam.ID_MODE_WIRE then return end
            self:SetActualID( value )
            local id = urtcam.GetIDByMode( self:GetActualID(), self:GetIDMode(), self:GetPlayer() )
            self:SetID( id )
        elseif name == "IDMode" then
            if self:GetIDMode() == urtcam.ID_MODE_WIRE then return end
            value = urtcam.NormalizeIDMode and urtcam.NormalizeIDMode(value) or math.Clamp( value, 0, 2 )
            self:SetIDMode( value )
            local id = urtcam.GetIDByMode( self:GetActualID(), self:GetIDMode(), self:GetPlayer() )
            self:SetID( id )
        end
    end

    util.AddNetworkString( "UltimateRT_Use" )

    function ENT:Use( activator, caller, useType )
        if not activator:IsPlayer() then return end

        net.Start( "UltimateRT_Use" )
            net.WriteEntity( self )
        net.Send( activator )
    end
end

if CLIENT then
    surface.CreateFont("URTCamFont", {
        font = "Courier New",
        size = 50,
        weight = 400,
        shadow = true
    })

    -- Belt-and-suspenders: create the client convars here too. The autorun
    -- file is the canonical place but if for any reason it didn't run (or ran
    -- in a context where these weren't created), this guarantees they exist
    -- before any hook below tries to use them.
    urtcam = urtcam or {}
    if not urtcam.cvDrawScreens then
        urtcam.cvDrawScreens = CreateClientConVar("urtcamera_drawscreens", "1", true, false, "Completely disabled drawing RT cameras", 0, 1)
    end
    if not urtcam.cvResolution then
        urtcam.cvResolution = CreateClientConVar("urtcamera_resolution", "512", true, false, "RT Monitor resolution. Requires restart", 0, 4096)
    end
    if not urtcam.cvRefreshRate then
        urtcam.cvRefreshRate = CreateClientConVar("urtcamera_refreshRate", "10", true, false, "Refresh rate of RT cameras. 0 = unlimited", 0, 120)
    end
    if not urtcam.cvDrawRange then
        urtcam.cvDrawRange = CreateClientConVar("urtcamera_drawrange", "1024", true, false, "Stop drawing RT monitors beyond this range. 0 = unlimited", 0)
    end
    if not urtcam.cvMaxRenderTargets then
        urtcam.cvMaxRenderTargets = CreateClientConVar("urtcamera_maxrendertargets", "50", true, false, "Maximum amount of active RT cameras. Dangerous setting!", 0)
    end

    local nextDrawTime = CurTime()

    local renderingRTCams = false

    hook.Add("ShouldDrawHalos", "UltimateRTCam:ShouldDrawHalos", function()
        if renderingRTCams then return false end
    end)

    local idsToDraw = {}

    hook.Add( "PostRender", "UltimateRTCam:Render", function()
        -- Defensive: in mixed-addon setups (workshop + override fork) the
        -- autorun's cvars can be nil briefly during load. Treat missing as
        -- "default enabled" so we don't error-spam the console.
        local cvDraw = urtcam and urtcam.cvDrawScreens
        if cvDraw and not cvDraw:GetBool() then idsToDraw = {} return end
        local cvRate = urtcam and urtcam.cvRefreshRate
        local rate = cvRate and cvRate:GetInt() or 10
        if rate != 0 then
            if UnPredictedCurTime() < nextDrawTime then idsToDraw = {} return end
            nextDrawTime = UnPredictedCurTime() + 1 / rate
        end

        renderingRTCams = true

        for id, _ in pairs( idsToDraw ) do
            local camera = urtcam.CamByID[ id ]

            if not IsValid( camera ) then continue end

            local target = urtcam.getTarget( id )

            if not target then continue end

            camera:SetNoDraw( true )
            render.PushRenderTarget( target.rt )
            render.OverrideAlphaWriteEnable( true, true )

            local size = target.rt:Width()

            render.RenderView( {
                origin = camera:GetPos(),
                angles = camera:GetAngles(),
                x = 0,
                y = 0,
                w = size,
                h = size,
                fov = camera:GetFOV(),
                drawviewmodel = false,
                drawviewer = true,
                -- zfar = 1000000
            } )

            render.OverrideAlphaWriteEnable( false )
            render.PopRenderTarget()
            camera:SetNoDraw( false )

            -- render.ClearDepth( true )
            -- render.Clear( 0, 0, 0, 0 )
        end

        renderingRTCams = false

        idsToDraw = {}
    end)

    local static = Material( "effects/tvscreen_noise002a" )

    ENT.IsActive = false

    function ENT:Draw()
        self:DrawModel()

        local meta = list.GetEntry( "RTMonitorModels", self:GetModel() )

        if not meta then return end

        cam.Start3D2D( self:LocalToWorld( meta.offset ), self:LocalToWorldAngles( meta.ang ), meta.scale )

        if not self.IsActive then
            surface.SetDrawColor( 0, 0, 0 )
            surface.DrawRect( -256 * meta.ratio, -256, 512 * meta.ratio, 512 )
            draw.SimpleText( "Press USE to enable monitor", "DermaLarge", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

            cam.End3D2D()
            return
        end

        local id = self:GetID()
        local cvRange = urtcam and urtcam.cvDrawRange
        local maxDist = cvRange and cvRange:GetInt() or 1024
        maxDist = maxDist * maxDist

        if maxDist != 0 and EyePos():DistToSqr( self:GetPos() ) > maxDist or not IsValid( urtcam.CamByID[ id ] ) or renderingRTCams then
            surface.SetDrawColor( 30, 30, 30 )
            surface.SetMaterial( static )
            surface.DrawRect( -256 * meta.ratio, -256, 512 * meta.ratio, 512 )
            surface.DrawTexturedRect( -256 * meta.ratio, -256, 512 * meta.ratio, 512 )

            if self:GetShowID() then
                draw.SimpleText( self:GetActualID(), "URTCamFont", -256 * meta.ratio + 30, -256 + 30, color_white, 0, 0, TEXT_ALIGN_LEFT )
            end

            cam.End3D2D()
            return
        end


        local target = urtcam.getTarget( id )
        if not target then return end

        idsToDraw[ id ] = true

        surface.SetDrawColor( 255, 255, 255 )

        surface.SetMaterial( target.mat )
        surface.DrawTexturedRect( -256 * meta.ratio, -256, 512 * meta.ratio, 512 )
        if self:GetShowID() then
            draw.SimpleText( self:GetActualID(), "URTCamFont", -256 * meta.ratio + 30, -256 + 30, color_white, 0, 0, TEXT_ALIGN_LEFT )
        end

        local screenFX = list.GetEntry( "RTScreenFX", self:GetScreenFX() )

        if screenFX then
            surface.SetDrawColor( 255, 255, 255, 255 )
            surface.SetMaterial( screenFX.mat )
            surface.DrawTexturedRect( -256 * meta.ratio, -256, 512 * meta.ratio, 512 )
        end

        cam.End3D2D()
    end

    net.Receive( "UltimateRT_Use", function()
        local ent = net.ReadEntity()
        if not IsValid( ent ) then return end
        ent.IsActive = not ent.IsActive
    end)
end