SWEP.PrintName = "FPV Tablet"
SWEP.Author = "晦涩弗里曼"
SWEP.Category = "#spawnmenu.category.other"
SWEP.Purpose = "Right click to save launch position, reload to launch the drone."

SWEP.Spawnable = true

SWEP.UseHands = true
SWEP.ViewModel = "models/v_item_pda.mdl"
SWEP.WorldModel = "models/v_item_pda.mdl"
SWEP.ViewModelFOV = 80
SWEP.SwayScale = 0.1
SWEP.BobScale = 0.1

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/hud/offpv_tablet")
    SWEP.DrawWeaponInfoBox = false
    SWEP.DrawCrosshair = false
    SWEP.DrawAmmo = false
    SWEP.BounceWeaponIcon = false
    SWEP.Slot = 0
    SWEP.SlotPos = 0
end

SWEP.CamPos = {}

local lastAngles = Angle(0, 0, 0)
local mapName = game.GetMap()

-- 定义网络消息
if SERVER then
    util.AddNetworkString("OFFPV_UpdateCamPos")

    hook.Add("SetupPlayerVisibility", "OFFPVRTCamera", function(ply)
        local target = ply:GetNWEntity("FPV_Rocket")
        if not IsValid(target) then return end

        AddOriginToPVS(target:GetPos())

        local att = target:LookupAttachment("eyes") or target:LookupAttachment("Eye")
        if att and att > 0 then
            local data = target:GetAttachment(att)
            if data and data.Pos then
                AddOriginToPVS(data.Pos)
            end
        end
    end)
end

function SWEP:Initialize()
    self:SetHoldType( "slam" )
    self.PDAOpen = false
    self.Weapon.GotRocket = false

    -- 确保CamPos存在，因为我不知道为什么有时会报错
    if not self.CamPos then
        self.CamPos = {}
    end

    -- 读取保存的发射位置
    if file.Exists("offpv_positions.json", "DATA") then
        local jsonData = file.Read("offpv_positions.json", "DATA")
        if jsonData then
            local camPosTable = util.JSONToTable(jsonData)
            if camPosTable then
                self.CamPos = camPosTable
            end
        end
    end

    -- 客户端接收更新
    if CLIENT then
        net.Receive("OFFPV_UpdateCamPos", function()
            local pos = net.ReadVector()
            self.CamPos[mapName] = pos
        end)
    end
end


function SWEP:Deploy()
    self:SetHoldType( "slam" )
    self:SendWeaponAnim(ACT_VM_HOLSTER)
    self:ResetSequence(self:LookupSequence("Holster"))
    self:EmitSound("offpv.unequip")
    self.PDAOpen = false

    return true
end

function SWEP:OpenAnim()
    self:SetHoldType( "camera" )
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:ResetSequence(self:LookupSequence("Draw"))
    self:EmitSound("offpv.equip")
end

function SWEP:PrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + 1)

    local rocket = self.Owner:GetNWEntity("FPV_Rocket")
    if IsValid(rocket) then
        rocket:EmitSound("offpv.ring")
        self:EmitSound("offpv.select")
    end
end

function SWEP:SecondaryAttack()
    if self:GetNextSecondaryFire() > CurTime() then return end
    self:SetNextSecondaryFire(CurTime() + 1)

    -- 如果火箭实体存在，则保存火箭位置，否则保存玩家位置
    local pos
    local rocket = self.Owner:GetNWEntity("FPV_Rocket")
    if IsValid(rocket) then
        pos = rocket:GetPos()
    else
        pos = self.Owner:GetShootPos()
    end
    self.CamPos[mapName] = pos

    -- 写入文件
    file.Write("offpv_positions.json", util.TableToJSON(self.CamPos))

    if SERVER then
        net.Start("OFFPV_UpdateCamPos")
            net.WriteVector(pos)
        net.Send(self.Owner)
    end
    self:EmitSound("offpv.select")
end

function SWEP:Reload()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + 1)
    -- 检查是否有保存的发射位置
    local pos = self.CamPos[mapName]
    if not pos then
        self:EmitSound("offpv.alert")
        return
    end
    self.PDAOpen = not self.PDAOpen

    if self.PDAOpen then
        self:OpenAnim()
        if not SERVER then return end
        timer.Simple(1, function()
            if not IsValid(self) or not IsValid(self.Weapon) then return end
        
            local rocket = ents.Create( "of_fpv" )
                rocket:SetOwner( self.Owner )
                rocket:SetPos(pos)  -- 使用保存的发射位置
                rocket:SetAngles( self.Owner:GetAngles() + Angle(10, 0, 0) )
                rocket:Spawn()
                rocket:Activate()
                rocket.myWeapon = self.Weapon
        
            local physObj = rocket:GetPhysicsObject()
            self.Owner:ViewPunch( Angle( math.Rand( 0, -10 ), math.Rand( 0, 0 ), math.Rand( 0, 0 ) ) )
            self.Weapon.GotRocket = true
            self.Owner:SetNWEntity("FPV_Rocket", rocket)
            rocket:EmitSound("offpv.deploy")
        end)
    else
        timer.Simple(0.2, function()
            if IsValid(self) and IsValid(self.Weapon) then
                self:Deploy()
            end
        end)
        local rocket = self.Owner:GetNWEntity("FPV_Rocket")
        if IsValid(rocket) then
            rocket.Attack = true
        end
    end
end

function SWEP:CalcView(player, pos, viewAngles, fov)
    local VModel = self:GetOwner():GetViewModel()
    local attachmentID = self:LookupAttachment("1")
    local attachment = self:GetAttachment(attachmentID)

    if attachment then
        local seqAct = VModel:GetSequenceActivity(VModel:GetSequence())
        if seqAct == ACT_VM_DRAW then
            local newAngle = attachment.Ang - self:GetAngles()
            lastAngles = LerpAngle(0.1, lastAngles, newAngle)
            viewAngles:Add(lastAngles)
        elseif seqAct == ACT_VM_HOLSTER then
            local newAngle = Angle(0, 0, 0)
            lastAngles = LerpAngle(0.1, lastAngles, newAngle)
            viewAngles:Add(lastAngles)
        end
    end

    return pos, viewAngles, fov
end

function SWEP:Holster()
    self.PDAOpen = false

    if IsValid(self.Owner) and IsValid(self.Owner:GetNWEntity("FPV_Rocket")) then
        self.Owner:GetNWEntity("FPV_Rocket").Attack = true
    end
    return true
end

function SWEP:OnRemove()
    if IsValid(self.Owner) and IsValid(self.Owner:GetNWEntity("FPV_Rocket")) then
        self.Owner:GetNWEntity("FPV_Rocket").Attack = true
    end
end

if CLIENT then
    surface.CreateFont("offpv_font", {size = 48 * ScrH() / 1080, weight = 300, antialias = true, extended = true, font = "LED Board-7"})

    local WorldModel = ClientsideModel(SWEP.WorldModel)
    WorldModel:SetNoDraw(true)

    function SWEP:DrawWorldModel()
        local _Owner = self:GetOwner()

        if IsValid(_Owner) then
            local offsetVec = Vector(-2, -5, -1.6)
            local offsetAng = Angle(15, 0, -165)
            local boneid = _Owner:LookupBone("ValveBiped.Bip01_R_Hand")
            if not boneid then return end

            local matrix = _Owner:GetBoneMatrix(boneid)
            if not matrix then return end

            local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())
            WorldModel:SetPos(newPos)
            WorldModel:SetAngles(newAng)
            WorldModel:SetupBones()
        else
            WorldModel:SetPos(self:GetPos())
            WorldModel:SetAngles(self:GetAngles())
        end

        WorldModel:DrawModel()
    end

    local x, y = ScrW()/1920, ScrH()/1080
    local widthFPV, heightFPV = y*1570, y*865

    OFFPV_RT = GetRenderTarget( "of_fpv", widthFPV, heightFPV )
    OFFPV_MAT = CreateMaterial( "of_fpv_tx", "UnlitGeneric", {
        [ "$basetexture" ] = "of_fpv",
    } )

    -- local OFFPV_MAT = Material( "models/weapons/sweps/stalker2/pda/mi_pda_screen" )
    -- local TEXTURE_SIZE_X = OFFPV_MAT:Width() / 4
    -- local TEXTURE_SIZE_Y = OFFPV_MAT:Height() / 4
    -- local OFFPV_RT = GetRenderTarget("OFFPV_MAT",TEXTURE_SIZE_X,TEXTURE_SIZE_Y)
    -- OFFPV_MAT:SetTexture("$basetexture",OFFPV_RT)

    function SWEP:RenderScreen()
        local viewOrigin, viewAngles
        local rocket = self.Owner:GetNWEntity("FPV_Rocket")
        if IsValid(rocket) then
            viewOrigin = rocket:GetPos() + rocket:GetForward() * 3
            viewAngles = rocket:GetAngles()
        elseif self.CamPos[mapName] then
            viewOrigin = self.CamPos[mapName]
            viewAngles = self:GetOwner():EyeAngles()
        end
        
        -- 在调用PopRenderTarget之前先PushRenderTarget
        render.PushRenderTarget(OFFPV_RT)
        
        offpv_drawing = true

        render.RenderView({
            origin = viewOrigin,
            angles = viewAngles
        })

        offpv_drawing = false

        render.OverrideAlphaWriteEnable( false )

        render.PopRenderTarget()
    end

    hook.Add("PostDrawOpaqueRenderables", "DrawFPVMarkers", function()
        local wep = LocalPlayer():GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "offpv_tablet" or IsValid(LocalPlayer():GetNWEntity("FPV_Rocket")) then return end
        
        if wep.CamPos[mapName] then
            local camPos = wep.CamPos[mapName]
            local plyPos = LocalPlayer():GetPos()
            local dist = camPos:Distance(plyPos)
            
            -- 定义显示范围
            local minDist = 150
            local maxDist = 500
            local nearFadeRange = 50
            local farFadeRange = 200
            
            -- 计算透明度
            local alpha = 0
            if dist > minDist and dist < maxDist then
                alpha = 255
            elseif dist <= minDist and dist > (minDist - nearFadeRange) then
                alpha = 255 * ((dist - (minDist - nearFadeRange)) / nearFadeRange)
            elseif dist >= maxDist and dist < (maxDist + farFadeRange) then
                alpha = 255 * (1 - ((dist - maxDist) / farFadeRange))
            end
            
            if alpha > 0 then
                cam.Start3D()
                    render.SetColorMaterial()
                    -- 绘制标记位置的边界框
                    local mis, mas = Vector(-10, -10, -10), Vector(10, 10, 10)
                    render.DrawBox(camPos, Angle(), mis, mas, Color(0, 0, 0, alpha * 0.4), true)
                    -- 在球形中心绘制FPV Logo
                    local logoMat = Material("of_fpv/fpv_logo_2.png")
                    if logoMat then
                        render.SetMaterial(logoMat)
                        render.DrawSprite(camPos, 20, 20, Color(255, 255, 255, alpha * 0.6))
                    end
                cam.End3D()
            end
        end
    end)

    function SWEP:DrawHUDBackground()
        if not IsValid(self.Owner:GetNWEntity("FPV_Rocket")) then return end
        
        -- 绘制FPV画面
        surface.SetMaterial( OFFPV_MAT )
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.DrawTexturedRect( ScrW()/2 - widthFPV/2, ScrH()/2 - heightFPV/2, widthFPV, heightFPV )

        local time = os.date("%H:%M:%S")
        local pos = self.Owner:GetNWEntity("FPV_Rocket"):GetPos()
        local posStr = string.format("X:%.0f Y:%.0f Z:%.0f", pos.x, pos.y, pos.z)
        local launchPos = self.CamPos[mapName] or Vector(0, 0, 0)
        local launchPosStr = string.format("X:%.0f Y:%.0f Z:%.0f", launchPos.x, launchPos.y, launchPos.z)

        -- 检查发射位置是否改变
        if self.lastLaunchPosStr ~= launchPosStr then
            self.lastLaunchPosStr = launchPosStr
            self.launchPosChangeTime = CurTime()
        end

        -- 计算颜色渐变
        local textColor = Color(255, 255, 255)
        if self.launchPosChangeTime then
            local elapsed = CurTime() - self.launchPosChangeTime
            if elapsed < 1 then
                local lerp = math.Clamp(elapsed * 2, 0, 1)
                textColor = Color(255 * (1 - lerp), 255, 255 * (1 - lerp))  -- 白色渐变到绿色
            elseif elapsed < 2 then
                local lerp = math.Clamp((elapsed - 1) * 2, 0, 1)
                textColor = Color(255 * lerp, 255, 255 * lerp)  -- 绿色渐变回白色
            end
        end

        surface.SetFont("offpv_font")
        surface.SetTextColor(textColor.r, textColor.g, textColor.b, 255)

        local fpvX = ScrW()/2 - widthFPV/2
        local fpvY = ScrH()/2 - heightFPV/2

        local launchPosWidth = surface.GetTextSize(launchPosStr)
        local timeWidth = surface.GetTextSize(time)
        local posWidth = surface.GetTextSize(posStr)
        local textHeight = select(2, surface.GetTextSize("W"))  -- 获取字体高度
        local textDock = textHeight * 0.25

        -- 绘制发射位置信息，左上角
        surface.SetTextPos(fpvX + textDock, fpvY + textDock)
        surface.DrawText(launchPosStr)

        -- 绘制时间信息，左下角
        surface.SetTextColor(255, 255, 255, 255)  -- 恢复白色
        surface.SetTextPos(fpvX + textDock, fpvY + heightFPV - textHeight - textDock)
        surface.DrawText(time)

        -- 绘制位置信息，右下角
        surface.SetTextPos(fpvX + widthFPV - posWidth - textDock, fpvY + heightFPV - textHeight - textDock)
        surface.DrawText(posStr)
    end

    hook.Add( "ShouldDrawLocalPlayer", "offpv_show", function( ply )
        if offpv_drawing then return true end --RT界面显示自己
    end )
end