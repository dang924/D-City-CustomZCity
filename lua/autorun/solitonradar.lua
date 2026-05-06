if SERVER then return end

-- ZCity permission gate: radar only renders if the server has granted it.
-- Grant: ply:SetNWBool("HasSolitonRadar", true)
-- Revoke: ply:SetNWBool("HasSolitonRadar", false)
local function ShouldShowRadar()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:GetNWBool("HasSolitonRadar", false)
end

if !ConVarExists("Soliton_scale") then
    CreateConVar("Soliton_scale", 1, FCVAR_ARCHIVE, "", 0.1)
end

if !ConVarExists("Soliton_step") then
    CreateConVar("Soliton_step", 8, FCVAR_ARCHIVE, "", 0)
end

if !ConVarExists("Soliton_tracehits") then
    CreateConVar("Soliton_tracehits", 5, FCVAR_ARCHIVE, "", 0)
end

if !ConVarExists("Soliton_refresh") then
    CreateConVar("Soliton_refresh", 2, FCVAR_ARCHIVE, "", 0)
end

if !ConVarExists("Soliton_enable") then
    CreateConVar("Soliton_enable", 1 , FCVAR_ARCHIVE)
end
--Цвета
if !ConVarExists("Soliton_colorWall_r") then --10, 255, 100
    CreateConVar("Soliton_colorWall_r", 10 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorWall_g") then
    CreateConVar("Soliton_colorWall_g", 255 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorWall_b") then
    CreateConVar("Soliton_colorWall_b", 100 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorWall_a") then
    CreateConVar("Soliton_colorWall_a", 255 , FCVAR_ARCHIVE, "", 0, 255)
end
--пропы
if !ConVarExists("Soliton_colorProp_r") then --230, 0, 255
    CreateConVar("Soliton_colorProp_r", 230 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorProp_g") then
    CreateConVar("Soliton_colorProp_g", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorProp_b") then
    CreateConVar("Soliton_colorProp_b", 255 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorProp_a") then
    CreateConVar("Soliton_colorProp_a", 255 , FCVAR_ARCHIVE, "", 0, 255)
end
--непеси
if !ConVarExists("Soliton_colorNPC_r") then --255,0,0
    CreateConVar("Soliton_colorNPC_r", 255 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorNPC_g") then
    CreateConVar("Soliton_colorNPC_g", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorNPC_b") then
    CreateConVar("Soliton_colorNPC_b", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorNPC_a") then
    CreateConVar("Soliton_colorNPC_a", 255 , FCVAR_ARCHIVE, "", 0, 255)
end
--бэкграунд
if !ConVarExists("Soliton_colorBackround_r") then --4,90,76,33
    CreateConVar("Soliton_colorBackround_r", 4 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorBackround_g") then
    CreateConVar("Soliton_colorBackround_g", 90 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorBackround_b") then
    CreateConVar("Soliton_colorBackround_b", 76 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorBackround_a") then
    CreateConVar("Soliton_colorBackround_a", 33 , FCVAR_ARCHIVE, "", 0, 255)
end
--линия
if !ConVarExists("Soliton_colorBackroundLine_r") then --0, 0, 0
    CreateConVar("Soliton_colorBackroundLine_r", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorBackroundLine_g") then
    CreateConVar("Soliton_colorBackroundLine_g", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorBackroundLine_b") then
    CreateConVar("Soliton_colorBackroundLine_b", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorBackroundLine_a") then
    CreateConVar("Soliton_colorBackroundLine_a", 255 , FCVAR_ARCHIVE, "", 0, 255)
end
--конус игрока
if !ConVarExists("Soliton_colorViewCone_r") then --0,255,166,43
    CreateConVar("Soliton_colorViewCone_r", 0 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorViewCone_g") then
    CreateConVar("Soliton_colorViewCone_g", 255 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorViewCone_b") then
    CreateConVar("Soliton_colorViewCone_b", 166 , FCVAR_ARCHIVE, "", 0, 255)
end

if !ConVarExists("Soliton_colorViewCone_a") then
    CreateConVar("Soliton_colorViewCone_a", 43 , FCVAR_ARCHIVE, "", 0, 255)
end

local ply
local scale = GetConVar("Soliton_scale"):GetFloat()
local step = GetConVar("Soliton_step"):GetFloat() * scale
local count = 0
local traceHits = GetConVar("Soliton_tracehits"):GetFloat()
local refresh = GetConVar("Soliton_refresh"):GetFloat()
local HightAbs = 414 * scale
local WidthAbs = 569 * scale
local CycleN = math.ceil((3940 * scale) / step)

local hight = HightAbs  --Длина вперёд на карте мгс         вперёд и назад - ось Y
local width = WidthAbs  -- Длина вправо (лево) на карте мгс   лево и право - ось Х
local scrX = ScrW() * (1689 / 1920) --середина радара по Х
local scrY = ScrH() * (116 / 720) --середина радара по Y
local colorProp = Color(GetConVar("Soliton_colorProp_r"):GetInt(), GetConVar("Soliton_colorProp_g"):GetInt(), GetConVar("Soliton_colorProp_b"):GetInt(), GetConVar("Soliton_colorProp_a"):GetInt())
local colorWall = Color(GetConVar("Soliton_colorWall_r"):GetInt(), GetConVar("Soliton_colorWall_g"):GetInt(), GetConVar("Soliton_colorWall_b"):GetInt(), GetConVar("Soliton_colorWall_a"):GetInt())
local colorRen = colorWall
local colorNPC = Color(GetConVar("Soliton_colorNPC_r"):GetInt(), GetConVar("Soliton_colorNPC_g"):GetInt(), GetConVar("Soliton_colorNPC_b"):GetInt() ,GetConVar("Soliton_colorNPC_a"):GetInt())
local colorPlayer = Color(251,255,25)
local colorBackround = Color(GetConVar("Soliton_colorBackround_r"):GetInt(), GetConVar("Soliton_colorBackround_g"):GetInt(), GetConVar("Soliton_colorBackround_b"):GetInt(), GetConVar("Soliton_colorBackround_a"):GetInt())
local colorBackroundLine = Color(GetConVar("Soliton_colorBackroundLine_r"):GetInt(), GetConVar("Soliton_colorBackroundLine_g"):GetInt(), GetConVar("Soliton_colorBackroundLine_b"):GetInt(), GetConVar("Soliton_colorBackroundLine_a"):GetInt())
local colorViewCone = Color(GetConVar("Soliton_colorViewCone_r"):GetInt(), GetConVar("Soliton_colorViewCone_g"):GetInt(), GetConVar("Soliton_colorViewCone_b"):GetInt(), GetConVar("Soliton_colorViewCone_a"):GetInt())
local NpcList = {}
local NpcListOld = {}
local NpcListREN = {}
local plyListOld = {}
local plyListREN = {}
local TraceList = {}
local TraceListOld = {}
local TraceN = 1
local Stage = -1
local plyPos = 0
local PixelKf = (0.3 * (ScrW() / 1920)) / (HightAbs / 414)

local TriangelKf = ScrW() / 1920
local angle = 0
local center = Vector(scrX,scrY,0)
local zero = Vector(0,-30,0)
local vertice = {{x = 0, y = 30}, {x = 100 * TriangelKf, y = 60},{x = 100 * TriangelKf ,y = 0}}
local START

local function TraceCashe(W, H, startPOS, plr, stepium)
    local hightV = Vector(W, H, 0)
    local goalPos = startPOS + hightV
    local trace = util.TraceLine({
        start = startPOS,
        endpos = goalPos,
        filter = {ply,"func_occluder"}
    })

    if trace.Hit then
        --получение цвета
        if trace.HitWorld then colorRen = colorWall
        elseif trace.Entity.IsNPC() or trace.Entity.IsNextBot() then colorRen = colorNPC
        elseif trace.Entity.IsPlayer() then colorRen = colorPlayer
        else colorRen = colorProp
        end

        --получение координат
        local point = Vector(scrX + (trace.HitPos.x - plr.x) * PixelKf, scrY - (trace.HitPos.y - plr.y) * PixelKf, 0)
        local rotate = 180 * math.atan(trace.HitNormal.x / trace.HitNormal.y) / math.pi

        TraceList[TraceN] = {point, rotate, trace.Fraction, colorRen} --сохраняем координаты в таблицу
        TraceN = TraceN + 1

        local fraction = trace.Fraction

        while trace.Fraction < 1 and count < traceHits do --продолжение трасировки пути
            local trace1 = util.TraceLine({
                start = trace.HitPos + Vector((goalPos.x - trace.HitPos.x) / 100, (goalPos.y - trace.HitPos.y) / 100, 0),
                endpos = goalPos,
                filter = {"func_breakable","func_breakable_surf","func_brush","func_button","func_door","func_door_rotating","func_ladder","func_monitor","func_movelinear","func_physbox","func_physbox_multiplayer","func_reflective_glass","func_rot_button","func_rotating","func_tank","func_wall","func_wall_toggle","func_water_analog"},
                whitelist = true
            })

            --если трейс начался в стене, то рендерим выход из стены
            if trace1.FractionLeftSolid > 0 and trace1.FractionLeftSolid < 1 then
                TraceList[TraceN] = {scrX + (trace1.StartPos.x - plr.x) * PixelKf, scrY - (trace1.StartPos.y - plr.y) * PixelKf}
                TraceN = TraceN + 1
            end

            if trace1.Hit and trace1.HitPos != goalPos then
                if trace1.HitNormal != vector_origin then --проверка не застрял ли трейс в модели
                    point = Vector(scrX + (trace1.HitPos.x - plr.x) * PixelKf, scrY - (trace1.HitPos.y - plr.y) * PixelKf, 0)
                    rotate = 180 * math.atan(trace1.HitNormal.x / trace1.HitNormal.y) / math.pi
                    fraction = fraction + (1 - fraction) * trace1.Fraction

                    TraceList[TraceN] = {point, rotate, fraction, trace.Fraction, colorWall}
                    TraceN = TraceN + 1
                else
                    trace1.HitPos = trace1.HitPos + Vector((goalPos.x - trace.HitPos.x) / 10,(goalPos.y - trace.HitPos.y) / 10, 0)
                end
            end
            trace = trace1
            count = count + 1
        end
        count = 0
    end
end

hook.Add("OnEntityCreated","NPCstart",function(ent)
    if ent:IsNextBot() or ent:IsNPC() then
        table.insert(NpcList, ent)
    end
end)

hook.Add("HUDPaint","Soliton",function()
    if not ShouldShowRadar() then return end
    if GetConVar("Soliton_enable"):GetInt() == 1 then
        ply = LocalPlayer()
        surface.SetDrawColor(colorBackroundLine)
        surface.DrawOutlinedRect(scrX - (ScrW() * (228 / 1280)) / 2-2, scrY - (ScrW() * (228 / 1280) * (414 / 569)) / 2-2, ScrW() * (228 / 1280) + 4, ScrW() * (228 / 1280) * (414 / 569) + 4, 2)
        draw.RoundedBox(0, scrX - (ScrW() * (228 / 1280)) / 2, scrY - (ScrW() * (228 / 1280) * (414 / 569)) / 2, ScrW() * (228 / 1280), ScrW() * (228 / 1280) * (414 / 569), colorBackround)

        local PartCycle = CycleN / refresh
        if Stage == -1 then
            START = Vector(ply:GetPos().x, ply:GetPos().y, ply:GetPos().z + 37)
            plyPos = ply:GetPos()

            local plyList = player.GetAll()

            plyListREN = {}
            local N = 1
            for k,v in ipairs(plyList) do --рендер игроков
                if math.abs(v:GetPos().x - plyPos.x) < WidthAbs and math.abs(v:GetPos().y - plyPos.y) < HightAbs then
                    local plyColor = Vector(v:GetPlayerColor().x * 255,v:GetPlayerColor().y * 255,v:GetPlayerColor().z * 255)
                    plyListREN[N] = {scrX + (v:GetPos().x - plyPos.x) * PixelKf - 4, scrY - (v:GetPos().y - plyPos.y) * PixelKf - 4, plyColor}
                    N = N + 1
                end
            end

            NpcListREN = {}
            local P = 1
            for k,v in ipairs(NpcList) do --рендер НИПов
                if v:IsValid() and math.abs(v:GetPos().x - plyPos.x) < WidthAbs and math.abs(v:GetPos().y - plyPos.y) < HightAbs then
                    NpcListREN[P] = {scrX + (v:GetPos().x - plyPos.x) * PixelKf - 4, scrY - (v:GetPos().y - plyPos.y) * PixelKf - 4}
                    P = P + 1
                elseif !v:IsValid() then
                    table.remove(NpcList, k)
                end
            end
            Stage = 0
        end

        --Рендер правой части
        while hight > -HightAbs and PartCycle > 0 and Stage == 0 do
            TraceCashe(width, hight, START, plyPos, step)
            PartCycle = PartCycle - 1

            hight = hight - step
            if hight <= -HightAbs then Stage = 1 end
        end

        if Stage == 1 then
        hight = -HightAbs
        Stage = 2
        end

        --Рендер нижней части
        while width > -WidthAbs and PartCycle > 0 and Stage == 2 do
            TraceCashe(width, hight, START, plyPos, step)
            PartCycle = PartCycle - 1

            width = width - step
            if width <= -WidthAbs then Stage = 3 end
        end

        if Stage == 3 then
            width = -WidthAbs
            Stage = 4
        end

        --Рендер левой части
        while hight < HightAbs and PartCycle > 0 and Stage == 4 do
            TraceCashe(width, hight, START, plyPos, step)
            PartCycle = PartCycle - 1

            hight = hight + step
            if hight >= HightAbs then Stage = 5 end
        end

        if Stage == 5 then
            hight = HightAbs
            Stage = 6
        end

        --Рендер верхней части
        while width < WidthAbs and PartCycle > 0 and Stage == 6 do
            TraceCashe(width, hight, START, plyPos, step)
            PartCycle = PartCycle - 1

            width = width + step
            if width >= WidthAbs then Stage = 7 end
        end

        if Stage == 7 then
            width = WidthAbs
        end


        local cone = Matrix()

        cone:Translate(center)
        cone:Rotate(Angle(0,angle,0))
        cone:Translate(zero)

        angle = -ply:GetLocalAngles().y

        cam.PushModelMatrix(cone)
            surface.SetDrawColor(colorViewCone)
            surface.DrawPoly(vertice)
        cam.PopModelMatrix()

        if Stage == 7 then
            --рендер нового кадра
            for k,v in ipairs(TraceList) do
                if TraceList[k][3] == nil then --рендер точки выхода
                    surface.DrawCircle(TraceList[k][1], TraceList[k][2], 1, colorWall)
                elseif TraceList[k][5] == nil then --рендер первого попадания
                    local line = Matrix()
                    line:Translate(TraceList[k][1])
                    line:Rotate(Angle(0, TraceList[k][2], 0))
                    line:Translate(Vector(-(step * TraceList[k][3] * PixelKf / 2), 0, 0))
                    cam.PushModelMatrix(line)
                        surface.SetDrawColor(TraceList[k][4])
                        surface.DrawLine(0,0, step * TraceList[k][3] * PixelKf, 0)
                    cam.PopModelMatrix()
                else --рендер последущих попаданий
                    local line = Matrix()
                    line:Translate(TraceList[k][1])
                    line:Rotate(Angle(0, TraceList[k][2], 0))
                    line:Translate(Vector(-(step * TraceList[k][3] * PixelKf / 2), 0, 0))
                    cam.PushModelMatrix(line)
                        surface.SetDrawColor(colorWall)
                        surface.DrawLine(0,0, step * TraceList[k][3] * PixelKf, 0)
                    cam.PopModelMatrix()
                end
            end
            TraceListOld = TraceList
            TraceList = {}
            TraceN = 1

            plyListOld = {}
            for k,v in ipairs(plyListREN) do --рендер игроков
                draw.RoundedBox(0, plyListREN[k][1], plyListREN[k][2], 8, 8, plyListREN[k][3])
                plyListOld[k] = plyListREN[k]
            end

            NpcListOld = {}
            for k,v in ipairs(NpcListREN) do --рендер НИПов
                draw.RoundedBox(0, NpcListREN[k][1], NpcListREN[k][2], 8, 8, colorNPC)
                NpcListOld[k] = NpcListREN[k]
            end
            Stage = -1

            scale = GetConVar("Soliton_scale"):GetFloat()
            step = GetConVar("Soliton_step"):GetFloat() * scale
            traceHits = GetConVar("Soliton_tracehits"):GetFloat()
            refresh = GetConVar("Soliton_refresh"):GetFloat()

            HightAbs = 414 * scale
            WidthAbs = 569 * scale

            CycleN = math.ceil((3940 * scale) / step)
            scrX = ScrW() * (1689 / 1920) --середина радара по Х
            scrY = ScrH() * (116 / 720) --середина радара по Y

            PixelKf = (0.3 * (ScrW() / 1920)) / (HightAbs / 414)
            TriangelKf = ScrW() / 1920
            center = Vector(scrX,scrY,0)
            vertice = {{x = 0, y = 30}, {x = 100 * TriangelKf, y = 60},{x = 100 * TriangelKf ,y = 0}}

            colorProp = Color(GetConVar("Soliton_colorProp_r"):GetInt(), GetConVar("Soliton_colorProp_g"):GetInt(), GetConVar("Soliton_colorProp_b"):GetInt(), GetConVar("Soliton_colorProp_a"):GetInt())
            colorWall = Color(GetConVar("Soliton_colorWall_r"):GetInt(), GetConVar("Soliton_colorWall_g"):GetInt(), GetConVar("Soliton_colorWall_b"):GetInt(), GetConVar("Soliton_colorWall_a"):GetInt())
            colorRen = colorWall
            colorNPC = Color(GetConVar("Soliton_colorNPC_r"):GetInt(), GetConVar("Soliton_colorNPC_g"):GetInt(), GetConVar("Soliton_colorNPC_b"):GetInt() ,GetConVar("Soliton_colorNPC_a"):GetInt())
            colorBackround = Color(GetConVar("Soliton_colorBackround_r"):GetInt(), GetConVar("Soliton_colorBackround_g"):GetInt(), GetConVar("Soliton_colorBackround_b"):GetInt(), GetConVar("Soliton_colorBackround_a"):GetInt())
            colorBackroundLine = Color(GetConVar("Soliton_colorBackroundLine_r"):GetInt(), GetConVar("Soliton_colorBackroundLine_g"):GetInt(), GetConVar("Soliton_colorBackroundLine_b"):GetInt(), GetConVar("Soliton_colorBackroundLine_a"):GetInt())
            colorViewCone = Color(GetConVar("Soliton_colorViewCone_r"):GetInt(), GetConVar("Soliton_colorViewCone_g"):GetInt(), GetConVar("Soliton_colorViewCone_b"):GetInt(), GetConVar("Soliton_colorViewCone_a"):GetInt())
        else
            --рендер старого кадра, чтобы не было мерцания
            for k,v in ipairs(TraceListOld) do
                if TraceListOld[k][3] == nil then
                    surface.DrawCircle(TraceListOld[k][1], TraceListOld[k][2], 1, colorWall)
                elseif TraceListOld[k][5] == nil then
                    local line = Matrix()
                    line:Translate(TraceListOld[k][1])
                    line:Rotate(Angle(0, TraceListOld[k][2], 0))
                    line:Translate(Vector(-(step * TraceListOld[k][3] * PixelKf / 2), 0, 0))
                    cam.PushModelMatrix(line)
                        surface.SetDrawColor(TraceListOld[k][4])
                        surface.DrawLine(0,0, step * TraceListOld[k][3] * PixelKf, 0)
                    cam.PopModelMatrix()
                else
                    local line = Matrix()
                    line:Translate(TraceListOld[k][1])
                    line:Rotate(Angle(0, TraceListOld[k][2], 0))
                    line:Translate(Vector(-(step * TraceListOld[k][3] * PixelKf / 2), 0, 0))
                    cam.PushModelMatrix(line)
                        surface.SetDrawColor(colorWall)
                        surface.DrawLine(0,0, step * TraceListOld[k][3] * PixelKf, 0)
                    cam.PopModelMatrix()
                end
            end

            for k,v in ipairs(plyListOld) do --рендер игроков
                draw.RoundedBox(0, plyListOld[k][1], plyListOld[k][2], 8, 8, plyListOld[k][3])
            end

            for k,v in ipairs(NpcListOld) do --рендер НИПов
                draw.RoundedBox(0, NpcListOld[k][1], NpcListOld[k][2], 8, 8, colorNPC)
            end
        end
    end
end)

hook.Add("PopulateToolMenu","SolitonMenu",function()
    spawnmenu.AddToolMenuOption("Options","Soliton Radar","Soliton_options","#soliton_settings.settings","","",function(panel)

        panel:CheckBox("#soliton_settings.enable", "Soliton_enable")

        panel:NumSlider("#soliton_settings.scale", "Soliton_scale", 0.1, 10, 1)
        panel:ControlHelp("#soliton_settings.scale.Help")

        panel:Help("#soliton_settings.perfomance")
        panel:ControlHelp("#soliton_settings.high")
        panel:ControlHelp("#soliton_settings.low")

        panel:NumSlider("#soliton_settings.step", "Soliton_step", 1, 128, 0)
        panel:ControlHelp("#soliton_settings.step.default")
        panel:ControlHelp("#soliton_settings.step.help")

        panel:NumSlider("#soliton_settings.tracehits", "Soliton_tracehits", 0, 50, 0)
        panel:ControlHelp("#soliton_settings.tracehits.default")
        panel:ControlHelp("#soliton_settings.tracehits.help")

        panel:NumSlider("#soliton_settings.refresh", "Soliton_refresh", 1, 1000, 0)
        panel:ControlHelp("#soliton_settings.refresh.default")
        panel:ControlHelp("#soliton_settings.refresh.help")

        panel:Help("#soliton_settings.Colors")
        panel:ColorPicker("#soliton_settings.WallColor", "Soliton_colorWall_r", "Soliton_colorWall_g", "Soliton_colorWall_b", "Soliton_colorWall_a")
        panel:ControlHelp("#soliton_settings.defaultWallColor")

        panel:ColorPicker("#soliton_settings.PropColor", "Soliton_colorProp_r", "Soliton_colorProp_g", "Soliton_colorProp_b", "Soliton_colorProp_a")
        panel:ControlHelp("#soliton_settings.defaultPropColor")

        panel:ColorPicker("#soliton_settings.NPCColor", "Soliton_colorNPC_r", "Soliton_colorNPC_g", "Soliton_colorNPC_b", "Soliton_colorNPC_a")
        panel:ControlHelp("#soliton_settings.defaultNPCColor")

        panel:ColorPicker("#soliton_settings.BackgroundColor", "Soliton_colorBackround_r", "Soliton_colorBackround_g", "Soliton_colorBackround_b", "Soliton_colorBackround_a")
        panel:ControlHelp("#soliton_settings.defaultBackgroundColor")

        panel:ColorPicker("#soliton_settings.BackgroundLineColor", "Soliton_colorBackroundLine_r", "Soliton_colorBackroundLine_g", "Soliton_colorBackroundLine_b", "Soliton_colorBackroundLine_a")
        panel:ControlHelp("#soliton_settings.defaultBackgroundLineColor")

        panel:ColorPicker("#soliton_settings.ViewConeColor", "Soliton_colorViewCone_r", "Soliton_colorViewCone_g", "Soliton_colorViewCone_b", "Soliton_colorViewCone_a")
        panel:ControlHelp("#soliton_settings.defaultViewConeColor")

    end)
end)