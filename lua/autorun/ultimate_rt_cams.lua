-- Force-send this file to clients. Required because the testing branch is
-- mounted via gameinfo.txt SearchPath, which doesn't auto-AddCSLuaFile
-- lua/autorun/*.lua the way a normal addons/ mount would. Without this
-- call, the cvars below only get created on the server, never on the
-- client, and the entity file's render hook errors every frame.
if SERVER then AddCSLuaFile() end

urtcam = urtcam or {}

urtcam.ID_MODE_GLOBAL = 0
urtcam.ID_MODE_PRIVATE = 1
urtcam.ID_MODE_LOCAL = 2
urtcam.ID_MODE_WIRE = 3

function urtcam.NormalizeIDMode(idmode)
    idmode = math.Round(tonumber(idmode) or urtcam.ID_MODE_GLOBAL)

    if idmode == urtcam.ID_MODE_LOCAL or idmode == urtcam.ID_MODE_WIRE then
        return idmode
    end

    return urtcam.ID_MODE_GLOBAL
end

function urtcam.ExtractActualID(fullID)
    fullID = tostring(fullID or "")
    if fullID == "" then return "" end

    if string.StartWith(fullID, "G_") then
        return string.sub(fullID, 3)
    end

    local privateActual = string.match(fullID, "^P_%d+_(.+)$")
    if privateActual and privateActual ~= "" then
        return privateActual
    end

    local localActual = string.match(fullID, "^C[P]?_%d+_(.+)$")
    if localActual and localActual ~= "" then
        return localActual
    end

    return fullID
end

function urtcam.NormalizeEntity(ent)
    if not IsValid(ent) then return false end
    if not ent.GetIDMode or not ent.SetIDMode or not ent.GetID or not ent.SetID then return false end

    local oldMode = tonumber(ent:GetIDMode()) or urtcam.ID_MODE_GLOBAL
    local newMode = urtcam.NormalizeIDMode(oldMode)
    local changed = false

    if newMode ~= oldMode then
        ent:SetIDMode(newMode)
        changed = true
    end

    if newMode == urtcam.ID_MODE_GLOBAL then
        local actualID = ent.GetActualID and ent:GetActualID() or ""
        if not isstring(actualID) or actualID == "" then
            actualID = urtcam.ExtractActualID(ent:GetID())
        end

        if actualID ~= "" then
            if ent.SetActualID then
                ent:SetActualID(actualID)
            end

            local expectedID = urtcam.GetIDByMode(actualID, newMode, ent.GetPlayer and ent:GetPlayer() or nil)
            if ent:GetID() ~= expectedID then
                ent:SetID(expectedID)
                changed = true
            end
        end
    end

    return changed
end

-- Admin migration helper: walks every rttv/rtcam entity and rewrites any with
-- IDMode = PRIVATE to use IDMode = GLOBAL plus a "G_<actualID>" full ID. Run
-- once after this fork is installed; perma-prop saves will pick up the new
-- state on next save.
if SERVER then
    local function normalizeLiveRTCams()
        local migrated = 0

        for _, className in ipairs({ "gmod_ultimate_rttv", "gmod_ultimate_rtcam" }) do
            for _, ent in ipairs(ents.FindByClass(className)) do
                if urtcam.NormalizeEntity(ent) then
                    migrated = migrated + 1
                end
            end
        end

        return migrated
    end

    concommand.Add("urtcam_migrate_private_to_global", function(ply)
        if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then
            ply:ChatPrint("[urtcam] Admin only.")
            return
        end
        local migrated = normalizeLiveRTCams()
        local msg = string.format("[urtcam] Migrated %d Private entities to Global. Re-save perma props to persist.", migrated)
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)

    hook.Add("InitPostEntity", "UltimateRTCam_NormalizeLegacyPrivate", function()
        local migrated = normalizeLiveRTCams()
        if migrated > 0 then
            print(string.format("[urtcam] Auto-normalized %d legacy private entities to global.", migrated))
        end
    end)

    hook.Add("OnEntityCreated", "UltimateRTCam_NormalizeLegacyPrivate", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end

            local className = ent:GetClass()
            if className ~= "gmod_ultimate_rttv" and className ~= "gmod_ultimate_rtcam" then return end

            urtcam.NormalizeEntity(ent)
        end)
    end)
end

function urtcam.GetIDByMode( actualID, idmode, ply )
    local id
    idmode = urtcam.NormalizeIDMode(idmode)

    -- ZScav fork: Private mode collapsed into Global. The per-player ID
    -- namespacing broke the bodycam director's expectation that all
    -- monitors with a given actualID share one full ID. Local/contraption
    -- mode still works for duplicator-spawned contraptions that need
    -- unique IDs per paste; everything else (Global, Private, Wire,
    -- unknown) resolves to "G_<actualID>".
    if idmode == urtcam.ID_MODE_LOCAL then
        if IsValid( ply ) then
            id = "CP_" .. ply:SteamID64() .. "_" .. actualID
        else
            id = "C_0_" .. actualID
        end
    else
        id = "G_" .. actualID
    end

    return id
end

if SERVER then
    urtcam.cvPVS = CreateConVar( "urtcamera_pvs", "1", FCVAR_ARCHIVE, "Adds the camera belonging to the nearest display to the player's PVS", 0, 1 )
else
    urtcam.cvDrawScreens = CreateClientConVar( "urtcamera_drawscreens", "1", true, false, "Completely disabled drawing RT cameras", 0, 1 )
    urtcam.cvResolution = CreateClientConVar( "urtcamera_resolution", "512", true, false, "RT Monitor resolution. Requires restart", 0, 4096 )
    urtcam.cvRefreshRate = CreateClientConVar( "urtcamera_refreshRate", "10", true, false, "Refresh rate of RT cameras. 0 = unlimited", 0, 120 )
    urtcam.cvDrawRange = CreateClientConVar( "urtcamera_drawrange", "1024", true, false, "Stop drawing RT monitors beyond this range. 0 = unlimited", 0 )
    urtcam.cvMaxRenderTargets = CreateClientConVar( "urtcamera_maxrendertargets", "50", true, false, "Maximum amount of active RT cameras. Dangerous setting!", 0 )
end

if CLIENT then
    local matParams = {
        [ "$ignorez" ] = 0,
        [ "$vertexcolor" ] = 1,
        [ "$nolod" ] = 1,
    }

    local function createRT( id )
        local res = urtcam.cvResolution:GetInt()
        local rt = GetRenderTarget( "urtcamera_" .. id, res, res )
        local mat = CreateMaterial( "urtcamera_" .. id, "UnlitGeneric", matParams )
        mat:SetTexture( "$basetexture", rt )
        return rt, mat
    end

    local targets = {}
    local nameToTarget = {}
    local targetToName = {}

    -- we have to do this because there"s no reliable way (without additional networking) to tell on client if an entity is *actually* removed
    -- it"s not gonna run that often so it"s ok
    local function tallyTargetUsage()
        local idToUsageCount = {}

        for _, ent in pairs( ents.FindByClass( "gmod_ultimate_rttv" ) ) do
            if not ent.IsActive then continue end
            local name = ent:GetID()
            local id = nameToTarget[ name ]
            if not id then continue end
            idToUsageCount[ id ] = ( idToUsageCount[ id ] or 0 ) + 1
        end

        return idToUsageCount
    end

    function urtcam.getTarget( name )
        if nameToTarget[ name ] then
            local targetID = nameToTarget[ name ]
            local target = targets[ targetID ]
            return target
        end

        local idToUsageCount = tallyTargetUsage()

        for targetID, target in ipairs( targets ) do
            if ( idToUsageCount[ targetID ] or 0 ) > 0 then continue end

            local oldName = targetToName[ targetID ]
            if oldName then
                nameToTarget[ oldName ] = nil
            end

            nameToTarget[ name ] = targetID
            targetToName[ targetID ] = name
            print( "[RT Cameras] Re-used RT #" .. targetID )
            return target
        end

        if #targets > urtcam.cvMaxRenderTargets:GetInt() then
            print( "[RT Cameras] Hit RT limit!" )
            return false
        end


        local targetID = #targets + 1

        local rt, mat = createRT( targetID )

        local target = {
            rt = rt,
            mat = mat
        }

        targets[ targetID ] = target

        nameToTarget[ name ] = targetID
        targetToName[ targetID ] = name

        print( "[RT Cameras] Created RT #" .. targetID )

        return target
    end
end

local function addRTMonitorModelIfExists( model, data )
    if not util.IsValidModel( model ) then return end

    list.Set( "RTMonitorModels", model, data )
end

addRTMonitorModelIfExists( "models/props_wasteland/controlroom_monitor001b.mdl", {
    offset = Vector( 7, 0, -6.5 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.034,
    ratio = 1.24,
} )

addRTMonitorModelIfExists( "models/props_lab/monitor01a.mdl", {
    offset = Vector( 12.3, 0, 4 ),
    ang = Angle( 0, 90, 85 ),
    scale = 0.033,
    ratio = 1.2,
} )

addRTMonitorModelIfExists( "models/props_lab/monitor02.mdl", {
    offset = Vector( 11.15, 0, 14.3 ),
    ang = Angle( 0, 90, 83 ),
    scale = 0.033,
    ratio = 1.2,
} )

addRTMonitorModelIfExists( "models/props/cs_assault/billboard.mdl", {
    offset = Vector( 1, 0, 0 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.25,
    ratio = 1.73,
} )

addRTMonitorModelIfExists( "models/props_combine/combine_monitorbay.mdl", {
    offset = Vector( -4, 3.5, 5 ),
    ang = Angle( 180, 90, 90 ),
    scale = 0.132 * 0.9,
    ratio = 1.15,
} )

addRTMonitorModelIfExists( "models/props_combine/combine_intmonitor003.mdl", {
    offset = Vector( 23, 0, 26 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.09,
    ratio = 0.75,
} )

-- EP2
addRTMonitorModelIfExists( "models/props_combine/combine_interface001a.mdl", {
    offset = Vector( 1, -2, 45 ),
    ang = Angle( 0, 90, 42 ),
    scale = 0.017,
    ratio = 1.8,
} )

-- CS:S
addRTMonitorModelIfExists( "models/props/cs_office/computer_monitor.mdl", {
    offset = Vector( 3.3, 0, 16.7 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.031,
    ratio = 1.4,
} )

addRTMonitorModelIfExists( "models/props/cs_office/tv_plasma.mdl", {
    offset = Vector( 6.5, 0, 18.5 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.132 * 0.5,
    ratio = 1.7,
} )

addRTMonitorModelIfExists( "models/props_c17/tv_monitor01.mdl", {
    offset = Vector( 5, -2, 0.5 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.023,
    ratio = 1.2,
} )

-- Wiremod
addRTMonitorModelIfExists( "models/blacknecro/tv_plasma_4_3.mdl", {
    offset = Vector( 0.05, 0, 0 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.132 * 0.63,
    ratio = 1.31,
} )

addRTMonitorModelIfExists( "models//expression 2/cpu_interface.mdl", {
    offset = Vector( 0, 0, 0.8 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.0075,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/kobilica/wiremonitorsmall.mdl", {
    offset = Vector( 0.2, 0, 5 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.017,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/kobilica/wiremonitorrtbig.mdl", {
    offset = Vector( 0.2, 0, 5 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.038,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/kobilica/wiremonitorbig.mdl", {
    offset = Vector( 0.2, 0, 13 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.045,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models//cheeze/pcb/pcb4.mdl", {
    offset = Vector( 0, 0, 0.35 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.0625,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models//cheeze/pcb/pcb7.mdl", {
    offset = Vector( 0, 0, 0.35 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.125,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/cheeze/pcb2/pcb8.mdl", {
    offset = Vector( 0, 0, 0.35 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.251,
    ratio = 0.99,
} )

---Sprops
addRTMonitorModelIfExists( "models/sprops/trans/lights/light_c2.mdl", {
    offset = Vector( 0.95, 0, 0 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.0054,
    ratio = 2,
} )

addRTMonitorModelIfExists( "models/sprops/trans/lights/light_c4.mdl", {
    offset = Vector( 1.9, 0, 0 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.0109,
    ratio = 2,
} )

---HL2

addRTMonitorModelIfExists( "models/props_lab/monitor01b.mdl", {
	offset = Vector(6.3, -1, 0.5),
	ang = Angle(0, 90, 90),
	scale = 0.018,
	ratio = 1,
})

addRTMonitorModelIfExists( "models/props_lab/workspace003.mdl", {
    offset = Vector( 16, 129, 84 ),
    ang = Angle( 0, 90, 100 ),
    scale = 0.05,
    ratio = 1.5,
} )

addRTMonitorModelIfExists( "models/props_lab/securitybank.mdl", {
    offset = Vector( 12, 9, 75 ),
    ang = Angle( 0, 90, 90 ),
    scale = 0.04,
    ratio = 1.5,
} )

addRTMonitorModelIfExists( "models/combine_room/combine_monitor003a.mdl", {
    offset = Vector( 135, 35, 0 ),
    ang = Angle( 0, 90, 92 ),
    scale = 0.69,
    ratio = 0.51,
} )

addRTMonitorModelIfExists( "models/combine_room/combine_monitor002.mdl", {
    offset = Vector( 53, 5, -1 ),
    ang = Angle( 0, 90, 92 ),
    scale = 0.36,
    ratio = 0.51,
} )

---Plastic plates

addRTMonitorModelIfExists( "models/hunter/plates/plate05x05.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.046,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate075x075.mdl", {
    offset = Vector( -5.9, -5.93, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.069,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate1x1.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.092,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate2x2.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.184,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate3x3.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.276,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate4x4.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.368,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate5x5.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.46,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate6x6.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.552,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate7x7.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.644,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate8x8.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.736,
    ratio = 1,
} )

addRTMonitorModelIfExists( "models/hunter/plates/plate5x8.mdl", {
    offset = Vector( 0, 0, 2 ),
    ang = Angle( 0, 90, 0 ),
    scale = 0.46,
    ratio = 8 / 5,
} )

-- ScreenFX
local order = 100
local function addScreenFX( id, name, mat, color )
    if CLIENT then language.Add( "rt.screenfx." .. id, name ) end
    list.Set( "RTScreenFX", id, {
        mat = Material( mat ),
        color = color or color_white,
        order = order
    } )

    order = order + 100
end

if CLIENT then
    CreateMaterial( "rtscreenfx_scanlines8", "UnlitGeneric", {
        [ "$basetexture" ] = "dev/dev_scanline",
        [ "$alpha" ] = 0.2,
        [ "proxies" ] = {
            [ "TextureScroll" ] = {
                [ "texturescrollvar" ] = "$basetexturetransform",
                [ "texturescrollrate" ] = 0.3,
                [ "texturescrollangle" ] = 270,
            }
        }
    } )
end

addScreenFX( "none", "None", "null" )
addScreenFX( "scanlines", "Scanlines", "!rtscreenfx_scanlines8" )
addScreenFX( "tvnoise", "TV Noise", "effects/tvscreen_noise002a" )
addScreenFX( "binocularoverlay", "Binocular Overlay", "effects/combine_binocoverlay" )
addScreenFX( "combineoverlay1", "Combine Overlay 1", "dev/dev_prisontvoverlay001" )
addScreenFX( "combineoverlay2", "Combine Overlay 2", "dev/dev_prisontvoverlay002" )
addScreenFX( "combineoverlay3", "Combine Overlay 3", "dev/dev_prisontvoverlay003" )
addScreenFX( "combineoverlay4", "Combine Overlay 4", "dev/dev_prisontvoverlay004" )