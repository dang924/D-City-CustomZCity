AddCSLuaFile()

SWEP.PrintName		= "#xdews.Weapon"
SWEP.Author 		= "LemonCola3424"

SWEP.ViewModelFOV	= 54
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/xdeedited/dontchangemybugbaitanim.mdl"
SWEP.WorldModel		= "models/xdews/shard.mdl"
SWEP.Spawnable		= true
SWEP.AdminOnly		= false

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "None"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "None"

SWEP.Weight					= 0
SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false

if CLIENT then
	SWEP.Slot				= 0
	SWEP.SlotPos			= 10
	SWEP.DrawAmmo			= false
	SWEP.DrawCrosshair		= false
	SWEP.UseHands           = true
	SWEP.SwayScale			= 1
	SWEP.BobScale			= 1

	local function lg( str )
		return language.GetPhrase( "xdews."..str )
	end

	local Logo = Material( "xdeedited/aperture256.png", "smooth mips" )
    function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )
		surface.SetDrawColor( 216, 216, 216, 255 )
		surface.SetMaterial( Logo )
		for i=1, 2 do
			surface.DrawTexturedRectRotated( x +wide/2, y +tall/2, tall*0.75, tall*0.75, 0 )
		end
    end

	SWEP.CL_HandPos 		= {
		[ "Pos" ] = Vector( 0, 0, 0 ), [ "Ang" ] = Angle( 2, 2, 12 ),
	}
	function SWEP:GetViewModelPosition( EyePos, EyeAng )
		local loc = self.CL_HandPos
		local own = self:GetOwner()
		local pp, aa = loc[ "Pos" ], loc[ "Ang" ]

		EyePos = EyePos +EyeAng:Forward()*math.sin( CurTime() )*0.2
		EyePos = EyePos +EyeAng:Up()*math.cos( CurTime()*2 )*0.1
		EyePos = EyePos +EyeAng:Right()*math.cos( CurTime() )*0.1

		EyeAng:RotateAroundAxis( EyeAng:Right(), aa.x +EyeAng.pitch/4 )
		EyeAng:RotateAroundAxis( EyeAng:Up(), aa.y )
		EyeAng:RotateAroundAxis( EyeAng:Forward(), aa.z )

		EyePos = EyePos +pp.x*EyeAng:Right()
		EyePos = EyePos +pp.y*EyeAng:Forward()
		EyePos = EyePos +pp.z*EyeAng:Up()

		return EyePos, EyeAng
	end

	SWEP.CL_Model 			= nil
	SWEP.CL_VMdlPos 		= {
		[ "Pos" ] = Vector( 3.2, -2.2, 0.4 ), [ "Ang" ] = Angle( -90, 80, 0 ), [ "Sca" ] = 0.25,
	}
	function SWEP:ViewModelDrawn( vm )
		if !IsValid( vm ) then return end
		local bone = vm:LookupBone( "ValveBiped.Bip01_R_Hand" )
		if !bone then return end
		local matrix = vm:GetBoneMatrix( bone )
		if !matrix then return end
		local loc = self.CL_VMdlPos

		if !IsValid( self.CL_Model ) then
			self.CL_Model = ClientsideModel( self.WorldModel, RENDERGROUP_BOTH )
			self.CL_Model:Spawn()
			self.CL_Model:SetModelScale( loc[ "Sca" ], 0 )
			self.CL_Model:SetParent( vm )
			self.CL_Model:SetNoDraw( true )
			self.CL_Model.CL_Base = self
			function self.CL_Model:GetRuneColor()
				local base = self.CL_Base
				return IsValid( base ) and base:GetRuneColor() or Vector( 0.5, 0.5, 0.5 )
			end
		else
			local NPos, NAng = LocalToWorld( loc[ "Pos" ], loc[ "Ang" ], matrix:GetTranslation(), matrix:GetAngles() )
			self.CL_Model:SetPos( NPos )
			self.CL_Model:SetAngles( NAng )
			self.CL_Model:DrawModel()

			if GetConVar( "xdews_cl_glowshard" ):GetBool() then
				local lit = DynamicLight( self.CL_Model:EntIndex() )
				if lit then
					local col = self:GetRuneColor()
					lit.pos = self.CL_Model:GetPos() +self.CL_Model:GetUp()*6
					lit.r = col.x*255
					lit.g = col.y*255
					lit.b = col.z*255
					lit.brightness = 1
					lit.decay = 100
					lit.size = 64
					lit.dietime = CurTime() +0.5
				end
			end
		end
	end

	SWEP.CL_WMdlPos 		= {
		[ "Pos" ] = Vector( 3, 2, -0.4 ), [ "Ang" ] = Angle( -90, 0, 180 ), [ "Sca" ] = 0.2,
	}
	function SWEP:DrawWorldModel()
		local own = self:GetOwner()
		if IsValid( own ) then
			own:SetupBones()
			own:InvalidateBoneCache()
			self:InvalidateBoneCache()
			self:WorldModelOffsetUpdate( own )
		end
		self:DrawModel()
	end
	function SWEP:WorldModelOffsetUpdate( ply )
		local loc = self.CL_WMdlPos
		
		if !IsValid( ply ) then
			self:SetRenderOrigin( nil )
			self:SetRenderAngles( nil )
			self:SetModelScale( loc[ "Sca" ], 0 )
			return
		end

		local bone = ply:LookupBone( "ValveBiped.Bip01_R_Hand" )
		if bone then
			local pos, ang
			local mat = ply:GetBoneMatrix( bone )
			if mat then pos, ang = mat:GetTranslation(), mat:GetAngles()
			else pos, ang = ply:GetBonePosition( bone ) end

			local opos, oang, oscale = loc[ "Pos" ], loc[ "Ang" ], loc[ "Sca" ]
			pos = pos +ang:Forward()*opos.x +ang:Right()*opos.y +ang:Up()*opos.z

			ang:RotateAroundAxis( ang:Up(), oang.pitch )
			ang:RotateAroundAxis( ang:Right(), oang.yaw )
			ang:RotateAroundAxis( ang:Forward(), oang.roll )

			self:SetRenderOrigin( pos )
			self:SetRenderAngles( ang )
			self:SetModelScale( oscale or 1, 0 )

			if GetConVar( "xdews_cl_glowshard" ):GetBool() then
				local lit = DynamicLight( self:EntIndex() )
				if lit then
					local col = self:GetRuneColor()
					lit.pos = pos
					lit.r = col.x*255
					lit.g = col.y*255
					lit.b = col.z*255
					lit.brightness = 1
					lit.decay = 500
					lit.size = 16
					lit.dietime = CurTime() +0.5
				end
			end
		end
	end
	
	SWEP.CL_Color = Vector( 0, 0, 0 )
	function SWEP:GetRuneColor()
		return self.CL_Color/255
	end
end

function SWEP:Initialize()
	self:SetHoldType( "slam" )
end

function SWEP:Deploy()
	self:SetHoldType( "slam" )
	if SERVER then
		self:DoAnim( "draw", GetConVar( "sv_defaultdeployspeed" ):GetFloat() )
	end
	return true
end

function SWEP:Holster( wep )
	if IsValid( self.CL_Model ) then
		self.CL_Model:Remove()
	end
	return true
end

function SWEP:PrimaryAttack()
	if self:GetNextPrimaryFire() > CurTime() then return end
	local own = self:GetOwner()
	if !IsValid( own ) or !own:IsPlayer() then return end

	if SERVER then
		self:DoAnim( "squeeze", 1 )
		self:DoGesture( ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL )
		if own:GetNWFloat( "XDEWS_CoolShard" ) > CurTime() then
			local tim = math.Round( own:GetNWFloat( "XDEWS_CoolShard" ) -CurTime(), 1 )
			xdews.hint( own, "#xdews.H_Cooldown", "", 1, { { "TIME", tim } } )
			own:EmitSound( "<physics/body/body_medium_strain"..math.random( 1, 2 )..".wav", 65, math.random( 120, 130 ), 0.3, CHAN_WEAPON )
		else
			own:EmitSound( "<ambient/levels/canals/windchime5.wav", 65, math.random( 110, 120 ), 0.9, CHAN_WEAPON )
			net.Start( "xdews_command" )
			net.WriteString( "teleport" )
			net.WriteString( util.TableToJSON( { self:EntIndex() } ) )
			net.Send( own )
		end
	end

	self:SetNextPrimaryFire( CurTime() +0.5 )
end

function SWEP:DoGesture( act )
	if CLIENT then return end
	local own = self:GetOwner()
	if !IsValid( own ) or !own:IsPlayer() then return end

	net.Start( "xdews_gesture" )
	net.WriteString( util.TableToJSON( { Target = own:EntIndex(), Act = act } ) )
	net.SendPVS( own:WorldSpaceCenter() )
end

function SWEP:DoAnim( anim, speed )
	local own = self:GetOwner()
	if !IsValid( own ) or !own:IsPlayer() then return end

	local vm = self:GetOwner():GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( anim ) )
	if speed < 0 then vm:SetCycle( 1 ) end
	vm:SetPlaybackRate( speed )
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Think()
	if CLIENT then
		local own = self:GetOwner()
		local col = Vector( 0, 0, 0 )
		if IsValid( own ) and own:IsPlayer() and own:GetNWFloat( "XDEWS_CoolShard" ) <= CurTime() then
			col = own:GetWeaponColor()
		end

		local anim = math.abs( math.sin( CurTime() ) )*0.25 +0.75
		local col = Vector( col.x*anim, col.y*anim, col.z*anim )
		self.CL_Color = LerpVector( 0.05, self.CL_Color, col*255 )
		self:NextThink( CurTime() +0.1 )
		self:SetNextClientThink( CurTime() +0.1 )
	end
	return true
end