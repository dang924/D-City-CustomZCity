-- cl_elite_radar.lua — Soliton radar restricted to John playerclass.
-- Only renders when the local player is Combine Elite (playerclass or JWick event).
-- Original Soliton radar by its author — adapted for ZCity John class integration.
-- Place in: lua/autorun/client/

if SERVER then return end

-- ── ConVars ───────────────────────────────────────────────────────────────────

local function CVar(name, default, ...)
    if not ConVarExists(name) then CreateConVar(name, default, FCVAR_ARCHIVE, ...) end
    return GetConVar(name)
end

local cv_enable    = CVar("Soliton_enable",    1)
local cv_scale     = CVar("Soliton_scale",     1,   "", 0.1)
local cv_step      = CVar("Soliton_step",      8,   "", 0)
local cv_tracehits = CVar("Soliton_tracehits", 5,   "", 0)
local cv_refresh   = CVar("Soliton_refresh",   2,   "", 0)

local cv_wall_r    = CVar("Soliton_colorWall_r",           10,  "", 0, 255)
local cv_wall_g    = CVar("Soliton_colorWall_g",           255, "", 0, 255)
local cv_wall_b    = CVar("Soliton_colorWall_b",           100, "", 0, 255)
local cv_wall_a    = CVar("Soliton_colorWall_a",           255, "", 0, 255)
local cv_prop_r    = CVar("Soliton_colorProp_r",           230, "", 0, 255)
local cv_prop_g    = CVar("Soliton_colorProp_g",           0,   "", 0, 255)
local cv_prop_b    = CVar("Soliton_colorProp_b",           255, "", 0, 255)
local cv_prop_a    = CVar("Soliton_colorProp_a",           255, "", 0, 255)
local cv_npc_r     = CVar("Soliton_colorNPC_r",            255, "", 0, 255)
local cv_npc_g     = CVar("Soliton_colorNPC_g",            0,   "", 0, 255)
local cv_npc_b     = CVar("Soliton_colorNPC_b",            0,   "", 0, 255)
local cv_npc_a     = CVar("Soliton_colorNPC_a",            255, "", 0, 255)
local cv_bg_r      = CVar("Soliton_colorBackround_r",      4,   "", 0, 255)
local cv_bg_g      = CVar("Soliton_colorBackround_g",      90,  "", 0, 255)
local cv_bg_b      = CVar("Soliton_colorBackround_b",      76,  "", 0, 255)
local cv_bg_a      = CVar("Soliton_colorBackround_a",      33,  "", 0, 255)
local cv_bgl_r     = CVar("Soliton_colorBackroundLine_r",  0,   "", 0, 255)
local cv_bgl_g     = CVar("Soliton_colorBackroundLine_g",  0,   "", 0, 255)
local cv_bgl_b     = CVar("Soliton_colorBackroundLine_b",  0,   "", 0, 255)
local cv_bgl_a     = CVar("Soliton_colorBackroundLine_a",  255, "", 0, 255)
local cv_vc_r      = CVar("Soliton_colorViewCone_r",       0,   "", 0, 255)
local cv_vc_g      = CVar("Soliton_colorViewCone_g",       255, "", 0, 255)
local cv_vc_b      = CVar("Soliton_colorViewCone_b",       166, "", 0, 255)
local cv_vc_a      = CVar("Soliton_colorViewCone_a",       43,  "", 0, 255)

-- ── State ─────────────────────────────────────────────────────────────────────

local scale      = cv_scale:GetFloat()
local step       = cv_step:GetFloat() * scale
local traceHits  = cv_tracehits:GetFloat()
local refresh    = cv_refresh:GetFloat()
local HightAbs   = 414 * scale
local WidthAbs   = 569 * scale
local CycleN     = math.ceil((3940 * scale) / step)
local hight      = HightAbs
local width      = WidthAbs
local scrX       = ScrW() * (1689 / 1920)
local scrY       = ScrH() * (116 / 720)
local PixelKf    = (0.3 * (ScrW() / 1920)) / (HightAbs / 414)
local TriangelKf = ScrW() / 1920
local angle      = 0
local center     = Vector(scrX, scrY, 0)
local zero       = Vector(0, -30, 0)
local vertice    = {{x=0,y=30},{x=100*TriangelKf,y=60},{x=100*TriangelKf,y=0}}
local count      = 0

local colorProp          = Color(cv_prop_r:GetInt(), cv_prop_g:GetInt(), cv_prop_b:GetInt(), cv_prop_a:GetInt())
local colorWall          = Color(cv_wall_r:GetInt(), cv_wall_g:GetInt(), cv_wall_b:GetInt(), cv_wall_a:GetInt())
local colorRen           = colorWall
local colorNPC           = Color(cv_npc_r:GetInt(), cv_npc_g:GetInt(), cv_npc_b:GetInt(), cv_npc_a:GetInt())
local colorPlayer        = Color(251, 255, 25)
local colorBackround     = Color(cv_bg_r:GetInt(), cv_bg_g:GetInt(), cv_bg_b:GetInt(), cv_bg_a:GetInt())
local colorBackroundLine = Color(cv_bgl_r:GetInt(), cv_bgl_g:GetInt(), cv_bgl_b:GetInt(), cv_bgl_a:GetInt())
local colorViewCone      = Color(cv_vc_r:GetInt(), cv_vc_g:GetInt(), cv_vc_b:GetInt(), cv_vc_a:GetInt())

local NpcList      = {}
local NpcListOld   = {}
local NpcListREN   = {}
local plyListOld   = {}
local plyListREN   = {}
local TraceList    = {}
local TraceListOld = {}
local TraceN       = 1
local Stage        = -1
local plyPos       = 0
local START

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ShouldShowRadar(ply)
    if not IsValid(ply) then return false end
    if ply:GetNWBool("ZC_IsCombineElite", false) then return true end
    -- Combine Elite subclass
    if ply.PlayerClassName == "Combine" and ply:GetNWString("PlayerRole", "") == "Elite" then return true end
    -- John Wick playerclass (coop or event)
    if ply.PlayerClassName == "John" then return true end
    -- JWick event role
    if ply.JWickRole == "john" then return true end
    return false
end

local function TraceCashe(W, H, startPOS, plr)
    local goalPos = startPOS + Vector(W, H, 0)
    local trace = util.TraceLine({
        start  = startPOS,
        endpos = goalPos,
        filter = {LocalPlayer(), "func_occluder"}
    })
    if not trace.Hit then return end

    if trace.HitWorld then
        colorRen = colorWall
    elseif trace.Entity:IsNPC() or trace.Entity:IsNextBot() then
        colorRen = colorNPC
    elseif trace.Entity:IsPlayer() then
        colorRen = colorPlayer
    else
        colorRen = colorProp
    end

    local point  = Vector(scrX + (trace.HitPos.x - plr.x) * PixelKf, scrY - (trace.HitPos.y - plr.y) * PixelKf, 0)
    local rotate = 180 * math.atan(trace.HitNormal.x / trace.HitNormal.y) / math.pi
    TraceList[TraceN] = {point, rotate, trace.Fraction, colorRen}
    TraceN = TraceN + 1

    local fraction = trace.Fraction
    while trace.Fraction < 1 and count < traceHits do
        local trace1 = util.TraceLine({
            start    = trace.HitPos + Vector((goalPos.x - trace.HitPos.x) / 100, (goalPos.y - trace.HitPos.y) / 100, 0),
            endpos   = goalPos,
            filter   = {"func_breakable","func_breakable_surf","func_brush","func_button","func_door","func_door_rotating","func_ladder","func_monitor","func_movelinear","func_physbox","func_physbox_multiplayer","func_reflective_glass","func_rot_button","func_rotating","func_tank","func_wall","func_wall_toggle","func_water_analog"},
            whitelist = true
        })
        if trace1.FractionLeftSolid > 0 and trace1.FractionLeftSolid < 1 then
            TraceList[TraceN] = {scrX + (trace1.StartPos.x - plr.x) * PixelKf, scrY - (trace1.StartPos.y - plr.y) * PixelKf}
            TraceN = TraceN + 1
        end
        if trace1.Hit and trace1.HitPos ~= goalPos then
            if trace1.HitNormal ~= vector_origin then
                point    = Vector(scrX + (trace1.HitPos.x - plr.x) * PixelKf, scrY - (trace1.HitPos.y - plr.y) * PixelKf, 0)
                rotate   = 180 * math.atan(trace1.HitNormal.x / trace1.HitNormal.y) / math.pi
                fraction = fraction + (1 - fraction) * trace1.Fraction
                TraceList[TraceN] = {point, rotate, fraction, trace.Fraction, colorWall}
                TraceN = TraceN + 1
            else
                trace1.HitPos = trace1.HitPos + Vector((goalPos.x - trace.HitPos.x) / 10, (goalPos.y - trace.HitPos.y) / 10, 0)
            end
        end
        trace = trace1
        count = count + 1
    end
    count = 0
end

local function RenderTraceLine(tbl, old)
    if tbl[3] == nil then
        surface.DrawCircle(tbl[1], tbl[2], 1, colorWall)
    elseif tbl[5] == nil then
        local line = Matrix()
        line:Translate(tbl[1])
        line:Rotate(Angle(0, tbl[2], 0))
        line:Translate(Vector(-(step * tbl[3] * PixelKf / 2), 0, 0))
        cam.PushModelMatrix(line)
            surface.SetDrawColor(tbl[4])
            surface.DrawLine(0, 0, step * tbl[3] * PixelKf, 0)
        cam.PopModelMatrix()
    else
        local line = Matrix()
        line:Translate(tbl[1])
        line:Rotate(Angle(0, tbl[2], 0))
        line:Translate(Vector(-(step * tbl[3] * PixelKf / 2), 0, 0))
        cam.PushModelMatrix(line)
            surface.SetDrawColor(colorWall)
            surface.DrawLine(0, 0, step * tbl[3] * PixelKf, 0)
        cam.PopModelMatrix()
    end
end

local function RefreshConVars()
    scale      = cv_scale:GetFloat()
    step       = cv_step:GetFloat() * scale
    traceHits  = cv_tracehits:GetFloat()
    refresh    = cv_refresh:GetFloat()
    HightAbs   = 414 * scale
    WidthAbs   = 569 * scale
    CycleN     = math.ceil((3940 * scale) / step)
    scrX       = ScrW() * (1689 / 1920)
    scrY       = ScrH() * (116 / 720)
    PixelKf    = (0.3 * (ScrW() / 1920)) / (HightAbs / 414)
    TriangelKf = ScrW() / 1920
    center     = Vector(scrX, scrY, 0)
    vertice    = {{x=0,y=30},{x=100*TriangelKf,y=60},{x=100*TriangelKf,y=0}}

    colorProp          = Color(cv_prop_r:GetInt(), cv_prop_g:GetInt(), cv_prop_b:GetInt(), cv_prop_a:GetInt())
    colorWall          = Color(cv_wall_r:GetInt(), cv_wall_g:GetInt(), cv_wall_b:GetInt(), cv_wall_a:GetInt())
    colorRen           = colorWall
    colorNPC           = Color(cv_npc_r:GetInt(), cv_npc_g:GetInt(), cv_npc_b:GetInt(), cv_npc_a:GetInt())
    colorBackround     = Color(cv_bg_r:GetInt(), cv_bg_g:GetInt(), cv_bg_b:GetInt(), cv_bg_a:GetInt())
    colorBackroundLine = Color(cv_bgl_r:GetInt(), cv_bgl_g:GetInt(), cv_bgl_b:GetInt(), cv_bgl_a:GetInt())
    colorViewCone      = Color(cv_vc_r:GetInt(), cv_vc_g:GetInt(), cv_vc_b:GetInt(), cv_vc_a:GetInt())
end

-- ── NPC tracking ──────────────────────────────────────────────────────────────

hook.Add("OnEntityCreated", "EliteRadar_NPCTrack", function(ent)
    if ent:IsNextBot() or ent:IsNPC() then
        table.insert(NpcList, ent)
    end
end)

-- ── HUD ───────────────────────────────────────────────────────────────────────

hook.Add("HUDPaint", "EliteRadar_Soliton", function()
    if cv_enable:GetInt() ~= 1 then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Only show for John playerclass or during JWick event as John
    if not ShouldShowRadar(ply) then return end

    surface.SetDrawColor(colorBackroundLine)
    surface.DrawOutlinedRect(
        scrX - (ScrW() * (228/1280)) / 2 - 2,
        scrY - (ScrW() * (228/1280) * (414/569)) / 2 - 2,
        ScrW() * (228/1280) + 4,
        ScrW() * (228/1280) * (414/569) + 4, 2)
    draw.RoundedBox(0,
        scrX - (ScrW() * (228/1280)) / 2,
        scrY - (ScrW() * (228/1280) * (414/569)) / 2,
        ScrW() * (228/1280),
        ScrW() * (228/1280) * (414/569),
        colorBackround)

    local PartCycle = CycleN / refresh

    if Stage == -1 then
        START  = Vector(ply:GetPos().x, ply:GetPos().y, ply:GetPos().z + 37)
        plyPos = ply:GetPos()

        plyListREN = {}
        local N = 1
        for _, v in ipairs(player.GetAll()) do
            if math.abs(v:GetPos().x - plyPos.x) < WidthAbs and
               math.abs(v:GetPos().y - plyPos.y) < HightAbs then
                local pc = v:GetPlayerColor()
                plyListREN[N] = {
                    scrX + (v:GetPos().x - plyPos.x) * PixelKf - 4,
                    scrY - (v:GetPos().y - plyPos.y) * PixelKf - 4,
                    Color(pc.x*255, pc.y*255, pc.z*255)
                }
                N = N + 1
            end
        end

        NpcListREN = {}
        local P = 1
        for k, v in ipairs(NpcList) do
            if IsValid(v) and
               math.abs(v:GetPos().x - plyPos.x) < WidthAbs and
               math.abs(v:GetPos().y - plyPos.y) < HightAbs then
                NpcListREN[P] = {
                    scrX + (v:GetPos().x - plyPos.x) * PixelKf - 4,
                    scrY - (v:GetPos().y - plyPos.y) * PixelKf - 4
                }
                P = P + 1
            elseif not IsValid(v) then
                table.remove(NpcList, k)
            end
        end
        Stage = 0
    end

    -- Scan right side
    while hight > -HightAbs and PartCycle > 0 and Stage == 0 do
        TraceCashe(width, hight, START, plyPos)
        PartCycle = PartCycle - 1
        hight = hight - step
        if hight <= -HightAbs then Stage = 1 end
    end
    if Stage == 1 then hight = -HightAbs Stage = 2 end

    -- Scan bottom
    while width > -WidthAbs and PartCycle > 0 and Stage == 2 do
        TraceCashe(width, hight, START, plyPos)
        PartCycle = PartCycle - 1
        width = width - step
        if width <= -WidthAbs then Stage = 3 end
    end
    if Stage == 3 then width = -WidthAbs Stage = 4 end

    -- Scan left side
    while hight < HightAbs and PartCycle > 0 and Stage == 4 do
        TraceCashe(width, hight, START, plyPos)
        PartCycle = PartCycle - 1
        hight = hight + step
        if hight >= HightAbs then Stage = 5 end
    end
    if Stage == 5 then hight = HightAbs Stage = 6 end

    -- Scan top
    while width < WidthAbs and PartCycle > 0 and Stage == 6 do
        TraceCashe(width, hight, START, plyPos)
        PartCycle = PartCycle - 1
        width = width + step
        if width >= WidthAbs then Stage = 7 end
    end
    if Stage == 7 then width = WidthAbs end

    -- View cone
    local cone = Matrix()
    cone:Translate(center)
    cone:Rotate(Angle(0, angle, 0))
    cone:Translate(zero)
    angle = -ply:GetLocalAngles().y
    cam.PushModelMatrix(cone)
        surface.SetDrawColor(colorViewCone)
        surface.DrawPoly(vertice)
    cam.PopModelMatrix()

    if Stage == 7 then
        -- Render new frame
        for _, v in ipairs(TraceList) do RenderTraceLine(v) end
        TraceListOld = TraceList
        TraceList    = {}
        TraceN       = 1

        plyListOld = {}
        for k, v in ipairs(plyListREN) do
            draw.RoundedBox(0, v[1], v[2], 8, 8, v[3])
            plyListOld[k] = v
        end

        NpcListOld = {}
        for k, v in ipairs(NpcListREN) do
            draw.RoundedBox(0, v[1], v[2], 8, 8, colorNPC)
            NpcListOld[k] = v
        end

        Stage = -1
        RefreshConVars()
    else
        -- Render previous frame to prevent flickering
        for _, v in ipairs(TraceListOld) do RenderTraceLine(v) end
        for _, v in ipairs(plyListOld) do
            draw.RoundedBox(0, v[1], v[2], 8, 8, v[3])
        end
        for _, v in ipairs(NpcListOld) do
            draw.RoundedBox(0, v[1], v[2], 8, 8, colorNPC)
        end
    end
end)

-- ── Settings menu ─────────────────────────────────────────────────────────────

hook.Add("PopulateToolMenu", "EliteRadar_SolitonMenu", function()
    spawnmenu.AddToolMenuOption("Options", "Soliton Radar", "Soliton_options",
        "#soliton_settings.settings", "", "", function(panel)
        panel:CheckBox("#soliton_settings.enable", "Soliton_enable")
        panel:NumSlider("#soliton_settings.scale",      "Soliton_scale",     0.1, 10,   1)
        panel:NumSlider("#soliton_settings.step",       "Soliton_step",      1,   128,  0)
        panel:NumSlider("#soliton_settings.tracehits",  "Soliton_tracehits", 0,   50,   0)
        panel:NumSlider("#soliton_settings.refresh",    "Soliton_refresh",   1,   1000, 0)
        panel:ColorPicker("#soliton_settings.WallColor",           "Soliton_colorWall_r",          "Soliton_colorWall_g",          "Soliton_colorWall_b",          "Soliton_colorWall_a")
        panel:ColorPicker("#soliton_settings.PropColor",           "Soliton_colorProp_r",          "Soliton_colorProp_g",          "Soliton_colorProp_b",          "Soliton_colorProp_a")
        panel:ColorPicker("#soliton_settings.NPCColor",            "Soliton_colorNPC_r",           "Soliton_colorNPC_g",           "Soliton_colorNPC_b",           "Soliton_colorNPC_a")
        panel:ColorPicker("#soliton_settings.BackgroundColor",     "Soliton_colorBackround_r",     "Soliton_colorBackround_g",     "Soliton_colorBackround_b",     "Soliton_colorBackround_a")
        panel:ColorPicker("#soliton_settings.BackgroundLineColor", "Soliton_colorBackroundLine_r", "Soliton_colorBackroundLine_g", "Soliton_colorBackroundLine_b", "Soliton_colorBackroundLine_a")
        panel:ColorPicker("#soliton_settings.ViewConeColor",       "Soliton_colorViewCone_r",      "Soliton_colorViewCone_g",      "Soliton_colorViewCone_b",      "Soliton_colorViewCone_a")
    end)
end)
