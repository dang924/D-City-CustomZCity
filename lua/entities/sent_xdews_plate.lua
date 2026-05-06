AddCSLuaFile()

ENT.PrintName   = "#xdews.Platform"
ENT.Author      = "LemonCola3424"
ENT.AdminOnly   = false

ENT.Category    = "#spawnmenu.category.fun_games"
ENT.Spawnable   = true

ENT.Base        = "base_anim"
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.SV_Killed   = false

function ENT:SpawnFunction( ply, tr, ClassName )
	if !tr.Hit then return end
    local ang = math.Round( ply:EyeAngles().yaw/90 )*90

	local ent = ents.Create( ClassName )
	ent:SetPos( tr.HitPos )
	ent:SetAngles( Angle( 0, ang, 0 ) )
	ent:Spawn()
	ent:Activate()
    
    local pos = tr.HitNormal
    local ang = tr.HitNormal:Angle()
    timer.Simple( 0, function()
        if !IsValid( ent ) then return end
        local pos = ent:GetPos() -pos
        pos = Vector( math.Round( pos.x, 1 ), math.Round( pos.y, 1 ), math.Round( pos.z ) )
        ang = Angle( ang.pitch +90, ang.yaw, ang.roll )
        ent:SetPos( pos )
        ent:SetAngles( ang )
    end )

	return ent
end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "Activated" ) // 是否已启用
    self:NetworkVar( "String", 0, "UID" ) // 石碑标识符
    self:NetworkVar( "String", 1, "Nick" ) // 石碑名称
    self:NetworkVar( "Vector", 0, "RColor" ) // 符文颜色
end

function ENT:Initialize()
    self:DrawShadow( true )
    if CLIENT then return end

    self:SetModel( "models/xdews/plate.mdl" )
    self:SetRenderMode( RENDERMODE_TRANSCOLOR )

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
    self:PhysWake()
    
    local phys = self:GetPhysicsObject()
    phys:SetMass( 50 )
    phys:EnableMotion( true )

    local hp = GetConVar( "xdews_sv_platehp" ):GetInt()
    if hp > 0 then
        self:SetMaxHealth( hp )
        self:SetHealth( self:GetMaxHealth() )
    end

    self:RefreshData()
end

function ENT:RefreshData()
    local uid = self:GetUID()
    if uid == "" then
        local str = string.Right( os.date( "%Y%m%d%H%M%S" , os.time() ), 16 )
        self:SetUID( "Pl_"..self:EntIndex().."_"..str )
        self:SetActivated( false )
        self:SetNick( "" )
        self:SetRColor( Vector( 0, 0, 0 ) )
    end
end

function ENT:OnDuplicated()
    self:RefreshData()
end

function ENT:OnRestore()
	if SERVER then
        self:RefreshData()
	end
end

function ENT:Use( act )
    if !IsValid( act ) or !act:IsPlayer() or act:GetUseEntity() != self then return end
    if !self:IsPlayerHolding() and !constraint.FindConstraint( self, "Weld" ) and self:GetPhysicsObject():IsMotionEnabled() then
        if act:KeyDown( IN_SPEED ) then
            act:PickupObject( self )
            return
        end
    end
    
    if !self:GetActivated() then
        net.Start( "xdews_command" )
        net.WriteString( "setup" )
        net.WriteString( util.TableToJSON( { self:EntIndex() } ) )
        net.Send( act )
    else
		if !istable( act.xdews_unlocks ) then
			act.xdews_unlocks = xdews.pl_load( act )
		end
        if !act.xdews_unlocks[ self:GetUID() ] then
            xdews.pl_unlock( act, self )
            return
        end
        if !GetConVar( "xdews_sv_useplate" ):GetBool() then return end
        
        net.Start( "xdews_command" )
        net.WriteString( "teleport" )
        net.WriteString( util.TableToJSON( { self:EntIndex() } ) )
        net.Send( act )
    end
end

function ENT:PhysicsCollide( dat, phy )
	if dat.Speed >= 120 and dat.DeltaTime > 0.2 then
		self:EmitSound( dat.Speed > 300 and "Concrete.ImpactHard" or "Concrete.ImpactSoft" )
	end
end

function ENT:Think()
    if CLIENT then self:SetNextClientThink( CurTime() +86400 ) end
    return true
end

function ENT:OnTakeDamage( dmg )
    if dmg:IsDamageType( DMG_BURN ) or dmg:IsDamageType( DMG_SLOWBURN ) then return end
    self:TakePhysicsDamage( dmg )
    if dmg:GetDamage() > 0 and self:GetMaxHealth() > 0 and self:Health() > 0 then
        self:SetHealth( math.max( 0, self:Health() -dmg:GetDamage() ) )
        if self:Health() <= 0 then self:Destroy() else self:EmitSound( "Concrete.BulletImpact" ) end
    end
end

function ENT:Destroy()
    if self.SV_Killed then return end
    self.SV_Killed = true

    local eff = { Ent = self:EntIndex(), Nor = self:GetRColor(), Name = "xdews_destroy" }
    net.Start( "xdews_effect" )
    net.WriteString( util.TableToJSON( eff ) )
    net.SendPVS( self:WorldSpaceCenter() )
    self:EmitSound( "Breakable.Concrete" )

    self:SetNotSolid( true )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetUID( "" )
    SafeRemoveEntityDelayed( self, 0.25 )
end

if SERVER then return end

function ENT:Draw()
    self:DrawModel()

    if halo.RenderedEntity() == self then return end

    if xdews then
        local col = Color( self:GetRColor().x, self:GetRColor().y, self:GetRColor().z )
        if ( IsValid( xdews.frame_cur ) and xdews.frame_cur.E_Target == self ) or ( IsValid( xdews.frame_select ) and xdews.frame_select.E_Target == self ) then
            xdews.outline_add( self, col, 2 )
        elseif IsValid( xdews.frame_select ) and xdews.frame_select.E_Target == self then
            xdews.outline_add( self, col, 2 )
        end
    end

    if !vgui.CursorVisible() and GetConVar( "xdews_cl_header" ):GetBool() and self:GetActivated() and !self.xdews_out and self:GetNick() != "" then
		if EyePos():DistToSqr( self:GetPos() ) <= 1024^2 and !LocalPlayer():ShouldDrawLocalPlayer() then
			local alp = math.Clamp( 1 -( EyePos():DistToSqr( self:WorldSpaceCenter() ) )/( 1024^2 ), 0, 1 )*255
			local p1, a1 = self:WorldSpaceCenter(), self:GetAngles()
			local yy = ( self:WorldSpaceCenter() -EyePos() ):Angle()
			local p2, a2 = LocalToWorld( Vector( 0, 0, 16 ), Angle( 0, yy.yaw -90, 90 ), p1, Angle( 0, 0, 0 ) )

            local cor = self:GetRColor()
			local col = Color( cor.x, cor.y, cor.z, alp )

			cam.Start3D2D( p2, a2, 0.05 )
                surface.SetFont( "xdews_Font3" )
                local ww, hh = surface.GetTextSize( self:GetNick() )
                draw.RoundedBoxEx( 32, -ww/2 -32, -hh/2, ww +64, hh +8, Color( 0, 0, 0, alp/2 ), true, true, false, false )
                if xdews and xdews.pl_sure( nil, self ) then
                    draw.RoundedBoxEx( 32, -ww/2 -32, -hh/2 +hh +8, ww +64, 16, col, false, false, false, false )
                end
				draw.SimpleTextOutlined( self:GetNick(), "xdews_Font3", 0, 0,
				Color( 255, 255, 255, alp ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, alp ) )
			cam.End3D2D()
        end
    end
end

function ENT:GetRuneColor()
    local col = Vector( 0.1, 0.1, 0.1 )
    if self:GetActivated() and xdews and xdews.pl_sure( nil, self ) then
        col = self:GetRColor()
        col = Vector( col.x/255, col.y/255, col.z/255 )
    end

    local anim = math.abs( math.sin( CurTime() ) )*0.25 +0.75
    return Vector( col.x*anim, col.y*anim, col.z*anim )
end