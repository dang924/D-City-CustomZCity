--[[
	Waystone Mod by LemonCola3424(XDE)
--]]
xdews = {}
xdews.version = "1.11"

if CLIENT then
	xdews.langs = {
		[ "en" ] = {
			[ "Pillar" ] = "Waystone Pillar",
			[ "Pillar2" ] = "Pillars can be locked to the map, only admins can place and save pillars\nPlayers can be teleported here via other waystones or using the shard",
			[ "Edit" ] = "Edit Waystone", [ "Destroy" ] = "Destroy Waystone",
			[ "Platform" ] = "Waystone Plate",
			[ "Platform2" ] = "Plates are temporary teleportation points\nPlayers can only be teleported here after touching the plate",
			[ "Weapon" ] = "Waystone Shard",

			[ "Cate" ] = "Waystone Mod", [ "ResetAll" ] = "Reset Everything",
			[ "CateSV" ] = "Serverside Settings", [ "InfoSV" ] = "Options for Waystone Mod, can only be changed by server host",
			[ "CateCL" ] = "Clientside Settings", [ "InfoCL" ] = "Options for Waystone Mod, only affects your own gaming experience",

			[ "cl_fade_1" ] = "Teleport Visual Effect", [ "cl_fade_2" ] = "Enable first-person visual effects during teleportation",
			[ "cl_effect_1" ] = "Teleport Fade Effect", [ "cl_effect_2" ] = "Enable third-person fade-in and fade-out effects during teleportation",
			[ "cl_particle_1" ] = "Partice Effects", [ "cl_particle_2" ] = "Enable particle effects such as unlocking and destroying Waystones",
			[ "cl_glowshard_1" ] = "Glowing Shard", [ "cl_glowshard_2" ] = "Waystone Shard will emit a faint dynamic light, the color depends on the player's weapon color",
			[ "cl_bright_1" ] = "Bright Teleport Visual", [ "cl_bright_2" ] = "It's best not to",
			[ "cl_header_1" ] = "Show Name", [ "cl_header_2" ] = "Display the name at the top of the stone",

			[ "sv_useplate_1" ] = "Allow Teleport via Plate", [ "sv_useplate_2" ] = "If enabled, players can use the Waystone Plate to teleport, cooldown is shared with the Pillar",
			[ "sv_usecommand_1" ] = "Allow Teleport via Command", [ "sv_usecommand_2" ] = "If enabled, players can use 'xdews' command to teleport, cooldown is shared with the Shard",
			[ "sv_customsay_1" ] = "Chat Command", [ "sv_customsay_2" ] = "Type this in chat box to open teleport menu. Allow teleport command must be enabled",
			[ "sv_altpillar_1" ] = "Alt Pillar Model", [ "sv_altpillar_2" ] = "Use a more optimized Waystone Pillar model",
			[ "sv_delay_1" ] = "Teleport Interval", [ "sv_delay_2" ] = "Total duration from initiation to completion of the teleportation",
			[ "sv_godtp_1" ] = "Invincible during Teleportation", [ "sv_godtp_2" ] = "During the teleportation interval, players are immune to all damage",
			[ "sv_camera_1" ] = "Preview Location", [ "sv_camera_2" ] = "Open a camera feed when selecting a location",

			[ "sv_coolpillar_1" ] = "Pillar Cooldown", [ "sv_coolpillar_2" ] = "You cannot use the Waystone Pillar again for a certain period of time",
			[ "sv_coolshard_1" ] = "Shard Cooldown", [ "sv_coolshard_2" ] = "You cannot use the Waystone Shard again for a certain period of time",
			[ "sv_platehp_1" ] = "Plate Health", [ "sv_platehp_2" ] = "Set this value to a number greater than 0 to allow the Waystone Plate to be destroyed",
		
			[ "H_AdminUse" ] = "Only admins can active this Waystone!",
			[ "H_AdminEdit" ] = "Only admins can edit this Waystone!",
			[ "H_AdminDestroy" ] = "Only admins can destroy this Waystone!",
			[ "H_NeedUnlock" ] = "You need to unlock it first!",
			[ "H_NoCommand" ] = "This command has been disabled by the server!",
			[ "H_Unlocked" ] = "Waystone Unlocked: %NAME%",
			[ "H_NotFound" ] = "Location not found!",
			[ "H_Cooldown" ] = "You need to wait %TIME% seconds before you can teleport again!",
			[ "H_Destroyed" ] = "Waystone Destroyed: %NAME%",
			[ "H_Edited" ] = "Waystone Edited: %NAME%",
			[ "H_Activated" ] = "Waystone Activated: %NAME%",
			[ "H_NoPass" ] = "Please note that if the Waystone is unlocked by default, the password won't work",
			[ "H_BadPass" ] = "Wrong password!",

			[ "M_SetupPillar" ] = "Setup Waystone",
			[ "M_SetupPlate" ] = "Setup Waystone Plate",
			[ "M_EditPillar" ] = "Edit Waystone",
			[ "M_EditPlate" ] = "Edit Waystone Plate",
			[ "M_LocationName" ] = "Location Name",
			[ "M_LocationNameH" ] = "Name this location...",
			[ "M_LocationInfo" ] = "Location Info",
			[ "M_LocationInfoH" ] = "Describe this location...",
			[ "M_Password" ] = "Password",
			[ "M_PasswordH" ] = "Requirement for unlocking...",
			[ "M_Unlocked" ] = "Unlock by default",
			[ "M_Persist" ] = "Save to Map",
			[ "M_Active" ] = "Active!",
			[ "M_Select" ] = "Select Location",
			[ "M_Search" ] = "Search...",

			[ "M_DestroyW" ] = "Destroy Waystone",
			[ "M_DestroyS" ] = "Are you sure you want to destroy %NAME% ?",
			[ "M_UnlockW" ] = "Unlock Waystone",
			[ "M_UnlockS" ] = "%NAME% needs a password to unlock!",
			[ "EnterPass" ] = "Enter password...",
			[ "M_Delete" ] = "Destroy", [ "M_Unlock" ] = "Unlock",
			[ "M_Cancel" ] = "Cancel", [ "M_Edit" ] = "Edit",

			[ "E_Setup" ] = "Setup Waystone",
			[ "E_Unlock" ] = "Unlock Waystone",
			[ "E_Teleport" ] = "Teleport",
		},

		[ "zh-cn" ] = {
			[ "Pillar" ] = "传送石碑",
			[ "Pillar2" ] = "传送石碑可以固定在地图上, 只有管理员可以放置并固定石碑\n玩家可以通过其他石碑或碎片传送到此处",
			[ "Edit" ] = "编辑石碑", [ "Destroy" ] = "摧毁石碑",
			[ "Platform" ] = "传送石板",
			[ "Platform2" ] = "传送石板为临时的传送点, 只有在玩家触摸该石板后才能使用",
			[ "Weapon" ] = "传送石碎片",

			[ "Cate" ] = "传送石碑模组", [ "ResetAll" ] = "全部重置",
			[ "CateSV" ] = "服务端选项", [ "InfoSV" ] = "调整传送石碑的相关选项, 只有服务器管理者可以调整这些内容",
			[ "CateCL" ] = "客户端选项", [ "InfoCL" ] = "调整传送石碑的相关选项, 仅影响你个人的游戏体验",

			[ "cl_fade_1" ] = "视觉效果", [ "cl_fade_2" ] = "启用传送时的第一人称视觉特效",
			[ "cl_bright_1" ] = "白色视觉", [ "cl_bright_2" ] = "最好不要",
			[ "cl_effect_1" ] = "传送效果", [ "cl_effect_2" ] = "启用传送时的第三人称渐入渐出特效",
			[ "cl_glowshard_1" ] = "碎片发光", [ "cl_glowshard_2" ] = "碎片将发出微弱的动态光, 颜色取决于玩家的武器色",
			[ "cl_particle_1" ] = "粒子特效", [ "cl_particle_2" ] = "启用解锁石碑、摧毁石板等粒子特效",
			[ "cl_header_1" ] = "显示地名", [ "cl_header_2" ] = "在石碑或石板的上方显示名称",

			[ "sv_useplate_1" ] = "允许使用石板传送", [ "sv_useplate_2" ] = "如果启用, 玩家可以通过传送石板发起传送, 冷却时间与石碑共享",
			[ "sv_usecommand_1" ] = "允许使用指令传送", [ "sv_usecommand_2" ] = "如果启用, 玩家可以通过 'xdews' 指令发起传送, 冷却时间与碎片共享",
			[ "sv_customsay_1" ] = "聊天指令", [ "sv_customsay_2" ] = "在聊天框输入该文本以打开传送菜单. 需要允许指令传送",
			[ "sv_altpillar_1" ] = "另一种石碑模型", [ "sv_altpillar_2" ] = "使用另一个更加优化的石碑模型",
			[ "sv_delay_1" ] = "传送间隔时间", [ "sv_delay_2" ] = "发起传送后渐入渐出共计时间",
			[ "sv_godtp_1" ] = "传送期间无敌", [ "sv_godtp_2" ] = "传送间隔期间, 玩家免疫任何伤害",
			[ "sv_camera_1" ] = "目的地检视", [ "sv_camera_2" ] = "在选择目的地时打开一个检视摄像头",

			[ "sv_coolpillar_1" ] = "石碑冷却时间", [ "sv_coolpillar_2" ] = "使用石碑后一段时间无法再次使用石碑",
			[ "sv_coolshard_1" ] = "碎片冷却时间", [ "sv_coolshard_2" ] = "使用碎片后一段时间无法再次使用碎片",
			[ "sv_platehp_1" ] = "石板血量", [ "sv_platehp_2" ] = "将该数值调至0以上, 石板可以被摧毁",

			[ "H_AdminUse" ] = "只有服务器管理员可以启动传送石碑!",
			[ "H_AdminEdit" ] = "只有服务器管理员可以编辑传送石碑!",
			[ "H_AdminDestroy" ] = "只有管理员可以摧毁传送石碑!",
			[ "H_NeedUnlock" ] = "你需要先解锁这块石碑!",
			[ "H_NoCommand" ] = "该指令已被服务器禁止!",
			[ "H_Unlocked" ] = "已解锁传送点: %NAME%",
			[ "H_NotFound" ] = "目的地不存在!",
			[ "H_CoolDown" ] = "你需要等待 %TIME% 秒才能再次传送!",
			[ "H_Destroyed" ] = "已摧毁传送点: %NAME%",
			[ "H_Edited" ] = "已编辑传送点: %NAME%",
			[ "H_Activated" ] = "已激活传送点: %NAME%",
			[ "H_NoPass" ] = "提醒一下, 如果设置了默认解锁, 密码是没有用的",
			[ "H_BadPass" ] = "密码错误!",

			[ "M_SetupPillar" ] = "初始化传送石碑",
			[ "M_SetupPlate" ] = "初始化传送石板",
			[ "M_EditPillar" ] = "编辑传送石碑",
			[ "M_EditPlate" ] = "编辑传送石板",
			[ "M_LocationName" ] = "地点名称",
			[ "M_LocationNameH" ] = "命名这个位置...",
			[ "M_LocationInfo" ] = "地点介绍",
			[ "M_LocationInfoH" ] = "简述这个位置...",
			[ "M_Password" ] = "密码",
			[ "M_PasswordH" ] = "输入密码才能解锁...",
			[ "M_Unlocked" ] = "默认解锁",
			[ "M_Persist" ] = "保存于地图",
			[ "M_Active" ] = "启动!",
			[ "M_Select" ] = "选择目的地",
			[ "M_Search" ] = "搜索...",

			[ "M_DestroyW" ] = "摧毁传送石碑",
			[ "M_DestroyS" ] = "确定要摧毁 %NAME% ?",
			[ "M_UnlockW" ] = "解锁传送石碑",
			[ "M_UnlockS" ] = "%NAME% 需要密码才能解锁!",
			[ "EnterPass" ] = "输入密码...",
			[ "M_Delete" ] = "摧毁", [ "M_Unlock" ] = "解锁",
			[ "M_Cancel" ] = "取消", [ "M_Edit" ] = "编辑",

			[ "E_Setup" ] = "初始化传送石碑",
			[ "E_Unlock" ] = "解锁传送石碑",
			[ "E_Teleport" ] = "传送",
		},
	}

	local lang = string.lower( GetConVar( "gmod_language" ):GetString() )
	if !xdews.langs[ lang ] then lang = "en" end
	for holder, text in pairs( xdews.langs[ lang ] ) do
		language.Add( "xdews."..holder, text )
	end
	
	matproxy.Add( {
		name = "RuneColor", 
		init = function( self, mat, values )
			self.ResultTo = values.resultvar
		end,
		bind = function( self, mat, ent )
			if ent.GetRuneColor then
				mat:SetVector( self.ResultTo, ent:GetRuneColor() )
			end
		end,
	} )

	sound.Add( {
		name = "xdews.Enter",
		channel = CHAN_BODY,
		volume = 0.5,
		level = 65,
		pitch = { 100, 105 },
		sound = {
			"player/portal_enter1.wav",
			"player/portal_enter2.wav"
		}
	} )

	sound.Add( {
		name = "xdews.Exit",
		channel = CHAN_BODY,
		volume = 0.5,
		level = 65,
		pitch = { 100, 105 },
		sound = {
			"player/portal_exit1.wav",
			"player/portal_exit2.wav"
		}
	} )

	surface.CreateFont( "xdews_Font0", { font = "Marlett", size = 20, weight = 512, extended = true, antialias = true } )
	surface.CreateFont( "xdews_Font1", { font = "Marlett", size = 24, weight = 512, extended = true, antialias = true } )
	surface.CreateFont( "xdews_Font2", { font = "Marlett", size = 32, weight = 512, extended = true, antialias = true } )
	surface.CreateFont( "xdews_Font3", { font = "Marlett", size = 128, weight = 512, extended = true, antialias = true } )
	surface.CreateFont( "xdews_Font4", { font = "Marlett", size = 192, weight = 512, extended = true, antialias = true } )
end

if CLIENT then
	hook.Add( "AddToolMenuCategories", "xdews_atmc", function()
		spawnmenu.AddToolCategory( "Utilities", "XDEWS", "#xdews.Cate" )
	end )

	hook.Add( "PopulateToolMenu", "xdews_ptm", function()
		spawnmenu.AddToolMenuOption( "Utilities", "XDEWS", "XDEWS_CL", "#xdews.CateCL", "", "", function( panel )
			panel:ClearControls()
			panel:Help( "#xdews.InfoCL" )
			local reset = panel:Button( "#xdews.ResetAll" )
			function reset:DoClick()
				RunConsoleCommand( "xdews_cl_fade", "1" )
				RunConsoleCommand( "xdews_cl_bright", "0" )
				RunConsoleCommand( "xdews_cl_effect", "1" )
				RunConsoleCommand( "xdews_cl_glowshard", "1" )
				RunConsoleCommand( "xdews_cl_particle", "1" )
				RunConsoleCommand( "xdews_cl_header", "1" )
			end
			panel:ControlHelp( "" )

			panel:CheckBox( "#xdews.cl_header_1", "xdews_cl_header" )
			panel:ControlHelp( "#xdews.cl_header_2" )
			panel:CheckBox( "#xdews.cl_fade_1", "xdews_cl_fade" )
			panel:ControlHelp( "#xdews.cl_fade_2" )
			panel:CheckBox( "#xdews.cl_effect_1", "xdews_cl_effect" )
			panel:ControlHelp( "#xdews.cl_effect_2" )
			panel:CheckBox( "#xdews.cl_particle_1", "xdews_cl_particle" )
			panel:ControlHelp( "#xdews.cl_particle_2" )
			panel:CheckBox( "#xdews.cl_glowshard_1", "xdews_cl_glowshard" )
			panel:ControlHelp( "#xdews.cl_glowshard_2" )
			panel:CheckBox( "#xdews.cl_bright_1", "xdews_cl_bright" )
			panel:ControlHelp( "#xdews.cl_bright_2" )
		end )

		spawnmenu.AddToolMenuOption( "Utilities", "XDEWS", "XDEWS_SV", "#xdews.CateSV", "", "", function( panel )
			panel:ClearControls()
			panel:Help( "#xdews.InfoSV" )
			local reset = panel:Button( "#xdews.ResetAll" )
			function reset:DoClick()
				RunConsoleCommand( "xdews_sv_useplate", "1" )
				RunConsoleCommand( "xdews_sv_usecommand", "1" )
				RunConsoleCommand( "xdews_sv_customsay", "!xdews" )
				RunConsoleCommand( "xdews_sv_altpillar", "0" )
				RunConsoleCommand( "xdews_sv_godtp", "1" )
				RunConsoleCommand( "xdews_sv_delay", "0.5" )
				RunConsoleCommand( "xdews_sv_coolpillar", "1" )
				RunConsoleCommand( "xdews_sv_coolshard", "1" )
				RunConsoleCommand( "xdews_sv_platehp", "0" )
				RunConsoleCommand( "xdews_sv_camera", "1" )
			end
			panel:ControlHelp( "" )

			panel:CheckBox( "#xdews.sv_useplate_1", "xdews_sv_useplate" )
			panel:ControlHelp( "#xdews.sv_useplate_2" )
			panel:CheckBox( "#xdews.sv_usecommand_1", "xdews_sv_usecommand" )
			panel:ControlHelp( "#xdews.sv_usecommand_2" )
			panel:TextEntry( "#xdews.sv_customsay_1", "xdews_sv_customsay" )
			panel:ControlHelp( "#xdews.sv_customsay_2" )
			panel:CheckBox( "#xdews.sv_altpillar_1", "xdews_sv_altpillar" )
			panel:ControlHelp( "#xdews.sv_altpillar_2" )
			panel:CheckBox( "#xdews.sv_godtp_1", "xdews_sv_godtp" )
			panel:ControlHelp( "#xdews.sv_godtp_2" )
			panel:CheckBox( "#xdews.sv_camera_1", "xdews_sv_camera" )
			panel:ControlHelp( "#xdews.sv_camera_2" )
			panel:NumSlider( "#xdews.sv_delay_1", "xdews_sv_delay", 0, 5, 1 )
			panel:ControlHelp( "#xdews.sv_delay_2" )
			panel:NumSlider( "#xdews.sv_coolpillar_1", "xdews_sv_coolpillar", 0, 600, 0 )
			panel:ControlHelp( "#xdews.sv_coolpillar_2" )
			panel:NumSlider( "#xdews.sv_coolshard_1", "xdews_sv_coolshard", 0, 600, 0 )
			panel:ControlHelp( "#xdews.sv_coolshard_2" )
			panel:NumSlider( "#xdews.sv_platehp_1", "xdews_sv_platehp", 0, 10000, 0 )
			panel:ControlHelp( "#xdews.sv_platehp_2" )
		end )
	end )

	net.Receive( "xdews_gesture", function()
		local dat = util.JSONToTable( net.ReadString() )
		local ply = Entity( tonumber( dat.Target ) )
		if !IsValid( ply ) or !ply:IsPlayer() or !ply:Alive() then return end
		local act = math.Round( tonumber( dat.Act ) )
		ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, math.Round( act ), true )
	end )

	net.Receive( "xdews_effect", function()
		local dat = util.JSONToTable( net.ReadString() )
		if !GetConVar( "xdews_cl_particle" ):GetBool() then return end

		local eff = EffectData()
		eff:SetMagnitude( dat.Mag or 1 )
		eff:SetScale( dat.Sca or 1 )
		eff:SetRadius( dat.Rad or 1 )
		eff:SetOrigin( dat.Pos or Vector() )
		eff:SetNormal( dat.Nor or Vector( 0, 0, 1 ) )
		if dat.Ent and IsValid( Entity( dat.Ent ) ) then
			eff:SetEntity( Entity( dat.Ent ) )
		end
		util.Effect( dat.Name, eff )
	end )

	net.Receive( "xdews_hint", function()
		xdews.hint( LocalPlayer(), net.ReadString(), net.ReadString(),
		math.Round( net.ReadFloat() ), util.JSONToTable( net.ReadString() ) )
	end )

	net.Receive( "xdews_command", function()
		local cmd = net.ReadString()
		local dat = util.JSONToTable( net.ReadString() )

		if cmd == "setup" then // 启动石碑
			local ent = Entity( tonumber( dat[ 1 ] ) )
			if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
			if !isfunction( ent.GetActivated ) or ent:GetActivated() then return end
			xdews.menu_setup( ent, ent:GetClass() == "sent_xdews_plate" )
		elseif cmd == "unlock" then // 解锁石碑
			local ent = xdews.findByUID( dat[ 1 ] )
			if !IsValid( ent ) then return end
			local nam = ( isstring( dat[ 2 ] ) and dat[ 2 ] != "" ) and dat[ 2 ] or "???"
			if ent:GetNick() != "" then nam = ent:GetNick() end
			xdews.hint( LocalPlayer(), "#xdews.H_Unlocked", "ambient/levels/canals/windchime2.wav", 0, { { "NAME", nam } } )
			xdews.points[ dat[ 1 ] ] = true
		elseif cmd == "load" then // 读取解锁信息
			xdews.points = dat
		elseif cmd == "teleport" then // 选择传送目的地
			local ent = Entity( tonumber( dat[ 1 ] ) )
			if !IsValid( ent ) then return end
			if string.StartWith( ent:GetClass(), "sent_xdews_" ) then
				if !isfunction( ent.GetActivated ) or !ent:GetActivated() then return end
				xdews.menu_select( ent )
			elseif ent == LocalPlayer() or string.StartWith( ent:GetClass(), "weapon_xdews_shard" ) then
				xdews.menu_select( ent )
			end
		elseif cmd == "detail" then // 获得细节
			if !IsValid( xdews.frame_select ) then return end
			xdews.frame_select:UpdateDetail( dat[ 1 ], dat )
		elseif cmd == "edit" then // 编辑石碑
			local ent = Entity( tonumber( dat[ 1 ] ) )
			if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
			if !isfunction( ent.GetActivated ) or !ent:GetActivated() then return end
			xdews.menu_setup( ent, ent:GetClass() == "sent_xdews_plate", dat[ 2 ] )
		elseif cmd == "destroy" then // 删除石碑
			local ent = Entity( tonumber( dat[ 1 ] ) )
			if !IsValid( ent ) or ent:GetClass() != "sent_xdews_pillar" then return end
			if !isfunction( ent.GetActivated ) or !ent:GetActivated() then return end
			xdews.menu_destroy( ent )
		elseif cmd == "password" then // 输入密码
			local ent = xdews.findByUID( dat[ 1 ] )
			if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
			if !isfunction( ent.GetActivated ) or !ent:GetActivated() then return end
			xdews.menu_password( ent )
		end
	end )

	xdews.mats = {
		[ "Grad" ] = Material( "gui/gradient_down" ),
		[ "Grad2" ] = Material( "xdeedited/ulgrad.png" ),
		[ "Cross" ] = Material( "xdeedited/cross32.png", "smooth mips" ),
		[ "Plus" ] = Material( "xdeedited/plus32.png", "smooth mips" ),
		[ "Sub" ] = Material( "xdeedited/sub32.png", "smooth mips" ),
		[ "Woah" ] = Material( "xdeedited/woah16.png", "smooth mips" ),
		[ "Pillar" ] = Material( "icon16/building.png", "smooth mips" ),
		[ "Plate" ] = Material( "icon16/house.png", "smooth mips" ),
		[ "Fade" ] = CreateMaterial( "xdews_fade", "UnlitGeneric", {
            [ "$basetexture" ]  = "vgui/zoom",
			[ "$translucent" ]  = 1,
            [ "$vertexcolor" ] 	= 1,
            [ "$vertexalpha" ] 	= 1,	
        } ),
		[ "FadeW" ] = Material( "xdeedited/zoomw" ),
		[ "Bright" ] = CreateMaterial( "xdews_bright0", "UnlitGeneric", {
            [ "$basetexture" ]  = "models/debug/debugwhite",
			[ "$translucent" ]  = 1,
        } ),
	}
	xdews.stys = {
		[ "Header" ] = Color( 0, 96, 192 ),
		[ "Text" ] = Color( 255, 255, 255 ),
		[ "Back" ] = Color( 192, 192, 192 ),
		[ "Panel" ] = Color( 128, 128, 128 ),
		[ "Entry" ] = Color( 64, 64, 64 ),
		[ "EntryTxt" ] = Color( 255, 255, 255 ),
	}

	function xdews.color_mul( col, mul ) // 颜色积
		return Color( math.Clamp( col.r*mul, 0, 255 ), math.Clamp( col.g*mul, 0, 255 ), math.Clamp( col.b*mul, 0, 255 ) )
	end

    function xdews.color_add( col, r, g, b, a ) // 颜色和
        if IsColor( r ) then
            return Color( math.Clamp( col.r +( r.r or 0 ), 0, 255 ), math.Clamp( col.r +( r.g or 0 ), 0, 255 ),
            math.Clamp( col.r +( r.b or 0 ), 0, 255 ), math.Clamp( col.r +( r.a or 0 ), 0, 255 ) )
        end
        return Color( math.Clamp( col.r +( r or 0 ), 0, 255 ), math.Clamp( col.g +( g or 0 ), 0, 255 ),
        math.Clamp( col.b +( b or 0 ), 0, 255 ), math.Clamp( col.a +( a or 0 ), 0, 255 ) )
    end

	function xdews.gui_frame( title, w, h, fw, fo ) // 基础窗口
		local frame = vgui.Create( "DFrame" )
		frame:SetKeyboardInputEnabled( true )
		frame:SetMouseInputEnabled( true )
		frame:MakePopup()
		frame:Show()

		frame:SetTitle( "" )
		frame:ShowCloseButton( false )
		frame:SetScreenLock( true )

		frame.B_Opened = true
		frame.N_Opening = SysTime() +0.2
		frame.N_Folding = 0
		frame.B_Folded = isbool( fo ) and fo or false
		frame.N_OrigW = w
		frame.N_FoldW = isnumber( fw ) and fw or 0
		frame.S_Title = title or ""
		frame.T_Buttons = {}

		local tfont = "xdews_Font1"
		surface.SetFont( tfont )
		local hew, heh = surface.GetTextSize( frame.S_Title )
		frame.N_Header = heh +8

		local sty = xdews.stys
		local ww = frame.B_Folded and frame.N_FoldW or frame.N_OrigW

		frame:SetAlpha( 1 )
		frame:AlphaTo( 255, 0.2 )
		frame:SetSize( ww, frame.N_Header )
		frame:SizeTo( ww, h, 0.2 )
		frame:SetPos( ScrW()/2 -ww/2, ScrH()/2 -( frame.N_Header/2 ) )
		frame:MoveTo( ScrW()/2 -ww/2, ScrH()/2 -( h/2 ), 0.2 )
		
		function frame:Paint( w, h ) // 渲染方法
			surface.SetDrawColor( sty[ "Header" ] )
			surface.DrawRect( 0, 0, w, self.N_Header )

			surface.SetMaterial( xdews.mats[ "Grad" ] )
			surface.SetDrawColor( xdews.color_mul( sty[ "Header" ], 1.2 ) )
			surface.DrawTexturedRect( 0, 0, w, self.N_Header )
					
			surface.SetDrawColor( sty[ "Back" ] )
			surface.DrawRect( 0, self.N_Header, w, h -self.N_Header )

			surface.SetDrawColor( xdews.color_mul( sty[ "Header" ], 0.6 ) )
			surface.DrawOutlinedRect( 0, 0, w, h )

			draw.SimpleText( frame.S_Title, tfont, 4, self.N_Header/2, sty[ "Text" ], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			frame:Paint2( w, h )
		end

		function frame:Paint2( w, h ) end // 自定义渲染

		function frame:DoClose() // 关闭方法
			if frame.N_Opening > SysTime() or !frame.B_Opened then return end
			frame:SetAlpha( 255 )
			frame:AlphaTo( 1, 0.1 )
			frame.B_Opened = false

			frame:SetKeyboardInputEnabled( false )
			frame:SetMouseInputEnabled( false )

			timer.Simple( 0.1, function()
				if !IsValid( frame ) or frame.B_Opened then return end
				frame:SetAlpha( 0 )
				frame:Remove()
			end )
		end

		function frame:OnFold( fold ) // 折叠接口方法
			return true
		end

		function frame:DoFold() // 折叠方法
			if frame.N_Opening > SysTime() or !frame.B_Opened then return end
			if frame.N_Folding > SysTime() then return end
			local fold = frame:OnFold( !frame.B_Folded )
			if fold == false then return end

			frame.B_Folded = !frame.B_Folded
			frame.N_Folding = SysTime() +0.2

			local wide = frame.B_Folded and frame.N_FoldW or frame.N_OrigW
			frame:SizeTo( wide, h, 0.2 )

			local ww, hh = frame:GetSize()
			local xx, yy = frame:GetPos()
			xx, yy = xx +( ww -wide )/2, yy

			xx, yy = math.Clamp( xx, 0, ScrW() -wide ), math.Clamp( yy, 0, ScrH() -hh )
			frame:MoveTo( xx, yy, 0.2 )

			for k, v in ipairs( frame.T_Buttons ) do
				v:MoveTo( wide -frame.N_Header*k, 0, 0.2 )
			end
		end

		for i=1, frame.N_FoldW > 0 and 2 or 1 do // 折叠与关闭按钮
			local siz = frame.N_Header
			local btn = vgui.Create( "DButton", frame )
			btn:SetPos( ww -siz*( i ), 0 )
			btn:SetSize( siz, siz )
			btn:SetText( "" )

			btn.B_Hover = false
			btn.N_Hover = 0
			btn.N_Click = 0

			function btn:Paint( w, h )
				local siz = math.max( 0, ( btn.N_Hover -SysTime() )/0.1 )
				local clk = math.max( 0, ( btn.N_Click -SysTime() )/0.2 )
				if btn.B_Hover then siz = 1-siz end
				siz = 0.9 +0.1*siz -0.2*clk

				surface.SetDrawColor( sty[ "Text" ] )
				if i == 1 then
					surface.SetMaterial( xdews.mats[ "Cross" ] )
				else
					surface.SetMaterial( xdews.mats[ frame.B_Folded and "Plus" or "Sub"] )
				end
				surface.DrawTexturedRectRotated( w/2, h/2, w*siz, h*siz, 0 )
			end

			function btn:OnCursorEntered()
				if btn.B_Hover then return end
				btn.N_Hover = SysTime() +0.1
				btn.B_Hover = true
			end

			function btn:OnCursorExited()
				if !btn.B_Hover then return end
				btn.N_Hover = SysTime() +0.1
				btn.B_Hover = false
			end

			function btn:DoClick()
				if !btn.B_Hover or btn.N_Click > SysTime() then return end
				btn.N_Click = SysTime() +0.2
				if i == 1 then frame:DoClose() else frame:DoFold() end
				surface.PlaySound( "ui/buttonclickrelease.wav" )
			end

			frame.T_Buttons[ i ] = btn
		end

		return frame
	end

	function xdews.gui_panel( base, x, y, w, h, bg ) // 板块部件
		local pan = vgui.Create( "DPanel", base or nil )
		pan:SetPos( x, y )
		pan:SetSize( w, h )

		local sty = xdews.stys
		function pan:Paint( w, h )
			if bg then
				surface.SetDrawColor( sty[ "Panel" ] )
				surface.DrawRect( 0, 0, w, h )
			end
			pan:Paint2( w, h )
		end

		function pan:Paint2( w, h ) end

		return pan
	end

	function xdews.gui_button( base, x, y, w, h, txt, ico, font ) // 按钮部件
		local pan = vgui.Create( "DButton", base or nil )
		pan:SetPos( x, y )
		pan:SetSize( w, h )
		pan:SetText( "" )

		local sty = xdews.stys

		pan.S_Text = txt or ""
		pan.M_Icon = ico or nil
		pan.S_Font = font or "xdews_Font2"
		pan.B_Lock = false
		pan.B_Spin = false

		pan.B_Hover = false
		pan.N_Hover = 0
		pan.N_Click = 0
		pan.C_Color = sty[ "Header" ]

		function pan:Paint2( w, h ) end

		function pan:Paint( w, h )
			local clk = math.max( ( pan.N_Click -SysTime() )/0.2, 0 )
			local hov = math.max( ( pan.N_Hover -SysTime() )/0.1, 0 )
			if pan.B_Hover then hov = 1-hov end

			local co1, co2 = pan.C_Color, sty[ "Text" ]
			if pan.B_Lock then
				co1 = sty[ "Back" ]
				co2 = xdews.color_add( Color( 255, 255, 255 ), -co2.r, -co2.g, -co2.b )
				hov, clk = 0, clk*2
			end

			if !pan.B_NoBack then
				surface.SetDrawColor( xdews.color_mul( co1, 1 +hov*0.2 -clk*0.2 ) )
				surface.DrawRect( 0, 0, w, h )

				if !pan.B_Lock then
					local grd = xdews.color_mul( co1, 1.4 +hov*0.4 )
					grd = xdews.color_add( grd, 0, 0, 0, -255*clk )
					surface.SetMaterial( xdews.mats[ "Grad2" ] )
					surface.SetDrawColor( grd )
					surface.DrawTexturedRect( 0, 0, w, h )
				end

				surface.SetDrawColor( xdews.color_mul( co1, 0.8 ) )
				surface.DrawOutlinedRect( 0, 0, w, h )
			end

			if pan.M_Icon != nil then
				surface.SetDrawColor( co2 )
				surface.SetMaterial( pan.M_Icon )
				if pan.S_Text == "" then
					surface.DrawTexturedRectRotated( w/2, h/2, h-16 -4*clk, h-16 -4*clk, pan.B_Spin and hov*10 or 0 )
				else
					surface.DrawTexturedRectRotated( h/2, h/2, h-16 -4*clk, h-16 -4*clk, pan.B_Spin and hov*10 or 0 )
				end
			end

			if pan.S_Text != "" then
				if pan.M_Icon != nil then
					draw.SimpleText( pan.S_Text, pan.S_Font, h, h/2, co2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				else
					draw.SimpleText( pan.S_Text, pan.S_Font, w/2, h/2, co2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				end
			end

			pan:Paint2( w, h )
		end

		function pan:DoClick2( lock ) end

		function pan:OnCursor( inn ) end

		function pan:OnCursorEntered()
			pan.N_Hover, pan.B_Hover = SysTime() +0.1, true
			pan:OnCursor( true )
		end

		function pan:OnCursorExited()
			pan.N_Hover, pan.B_Hover = SysTime() +0.1, false
			pan:OnCursor( false )
		end

		function pan:DoClick()
			if pan.B_Hover and !pan.B_Lock then
				pan:DoClick2()
				pan.N_Click = SysTime() +0.2
			end
		end

		return pan
	end

	function xdews.gui_entry( base, x, y, w, h, def, len, hol ) // 输入框部件
		local pan = vgui.Create( "DPanel", base or nil )
		pan:SetPos( x, y )
		pan:SetSize( w, h )
		pan:SetText( "" )

		local sty = xdews.stys

		pan.N_Length = len or 256
		pan.S_Value = def or ""
		pan.S_Font = "xdews_Font0"
		pan.S_Holder = hol or ""

		local co1 = sty[ "Entry" ]
		local co2 = sty[ "Header" ]
		local co3 = sty[ "Header" ]
		local co4 = sty[ "EntryTxt" ]

		local txt = vgui.Create( "DTextEntry", pan )
		txt:Dock( FILL )
		txt:SetFont( pan.S_Font )
		txt:SetUpdateOnType( true )
		txt:SetPaintBackground( false )
		txt:SetTextColor( co4 )
		txt:SetCursorColor( co4 )
		pan.P_Entry = txt

		txt:SetPlaceholderColor( xdews.color_add( co4, 0, 0, 0, -192 ) )
		txt:SetPlaceholderText( pan.S_Holder )
		txt:SetHighlightColor( xdews.color_add( co4, 0, 0, 0, -192 ) )

		function txt:OnValueChange( val )
			if pan.N_Length > 0 and string.len( val ) > pan.N_Length then
				txt:SetText( pan.S_Value ) return
			end
			if pan.B_Numeric then
				local num = tonumber( val )
				if !isnumber( num ) then
					txt:SetText( pan.S_Value ) return
				end
			end
			pan:OnChange( val, pan.S_Value )
			pan.S_Value = val
		end

		function pan:OnChange( val, old ) end

		function pan:GetValue() return pan.S_Value end

		function pan:SetValue( val )
			if !isstring( val ) then return end
			pan:OnChange( val, pan.S_Value )
			txt:SetValue( val )
		end

		pan:SetValue( pan.N_Value )

		function pan:Paint( w, h )
			surface.SetDrawColor( co1 )
			surface.DrawRect( 0, 0, w, h )
			surface.SetDrawColor( co2 )
			surface.DrawOutlinedRect( 0, 0, w, h )
		end

		return pan, txt
	end

	function xdews.gui_checker( base, x, y, w, h, on ) // 勾选框部件
		local pan = vgui.Create( "DButton", base or nil )
		pan:SetPos( x, y )
		pan:SetSize( w, h )
		pan:SetText( "" )

		local sty = xdews.stys

		pan.B_Value = on or false
		pan.N_Click = 0

		local col = xdews.color_mul( sty[ "Header" ], 1.5 )

		function pan:Paint( w, h )
			local ler = math.max( ( pan.N_Click -SysTime() )/0.1, 0 )
			local le2 = !pan.B_Value and 1-ler or ler

			surface.SetDrawColor( sty[ "Entry" ] )
			surface.DrawRect( 0, 0, w, h )

			surface.SetDrawColor( sty[ "Header" ] )
			surface.DrawOutlinedRect( 0, 0, w, h )

			surface.SetDrawColor( col )
			draw.NoTexture()
			surface.DrawTexturedRectRotated( w/2, h/2, w*0.75*( 1-le2 ), h*0.75*( 1-le2 ), 0 )
		end

		function pan:OnChange( val, old ) end

		function pan:GetValue() return pan.B_Value end

		function pan:SetValue( val )
			if !isbool( val ) then return end
			pan:OnChange( val, pan.B_Value )
			pan.B_Value = val
		end

		function pan:DoClick()
			if pan.N_Click > SysTime() then return end
			pan:SetValue( !pan:GetValue() )
			pan.N_Click = SysTime() +0.1
		end

		if def then pan:SetValue( def ) end
		return pan
	end

	function xdews.menu_setup( ent, plate, old ) // 初始化石碑
		local configs = {
			{ "#xdews.M_LocationName", 36, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local prt, ent = xdews.gui_entry( pan, ww -220 -2, 2, 220, 32, "", 64, language.GetPhrase( "xdews.M_LocationNameH" ) )
				
				if istable( dat ) then
					ent:SetValue( dat.Name or "" )
				end

				function prt:OnChange( val )
					frm.T_Data[ "Name" ] = val
				end
				frm.T_Data[ "Name" ] = prt:GetValue()
			end },
			{ "#xdews.M_LocationInfo", 108, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local prt, ent = xdews.gui_entry( pan, ww -220 -2, 2, 220, 104, "", 1024, language.GetPhrase( "xdews.M_LocationInfoH" ) )
				ent:SetMultiline( true )
				
				if istable( dat ) then
					ent:SetValue( dat.Info or "" )
				end

				function prt:OnChange( val )
					frm.T_Data[ "Info" ] = val
				end
				frm.T_Data[ "Info" ] = prt:GetValue()
			end },
			{ "#xdews.M_Password", 36, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local prt, ent = xdews.gui_entry( pan, ww -220 -2, 2, 220, 32, "", 32, language.GetPhrase( "xdews.M_PasswordH" ) )
				
				function prt:OnChange( val )
					frm.T_Data[ "Password" ] = val
					RunConsoleCommand( "xdews_pr_password", val )
				end

				if istable( dat ) then
					prt:SetValue( dat.Password or "" )
				else
					local var = GetConVar( "xdews_pr_password" ):GetString()
					prt:SetValue( var )
				end

				frm.T_Data[ "Password" ] = prt:GetValue()
			end },
			{ "#xdews.M_Unlocked", 36, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local prt = xdews.gui_checker( pan, ww -32 -2, 2, 32, 32, false )
				
				function prt:OnChange( val )
					frm.T_Data[ "Unlocked" ] = val
					RunConsoleCommand( "xdews_pr_unlocked", val and "1" or "0" )
				end

				if istable( dat ) then
					prt:SetValue( dat.Unlocked or false )
				else
					local var = GetConVar( "xdews_pr_unlocked" ):GetBool()
					prt:SetValue( var )
				end

				frm.T_Data[ "Unlocked" ] = prt:GetValue()
			end },
			{ "#xdews.M_Persist", 36, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local prt = xdews.gui_checker( pan, ww -32 -2, 2, 32, 32, true )
				
				function prt:OnChange( val )
					frm.T_Data[ "Persist" ] = val
					RunConsoleCommand( "xdews_pr_persist", val and "1" or "0" )
				end

				if istable( dat ) then
					prt:SetValue( dat.Persist or true )
				else
					local var = GetConVar( "xdews_pr_persist" ):GetBool()
					prt:SetValue( stvarr )
				end

				frm.T_Data[ "Persist" ] = prt:GetValue()
			end },
			{ " ", 108, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local prt = pan:Add( "DColorMixer" )
				prt:Dock( FILL )
				prt:SetPalette( true )
				prt:SetAlphaBar( false )
				prt:SetWangs( true )
				
				local col = Color( 0, 162, 255 )
				prt:SetColor( col )

				function prt:ValueChanged( val )
					frm.T_Data[ "Color" ] = Vector( val.r, val.g, val.b )
					RunConsoleCommand( "xdews_pr_color", val.r.." "..val.g.." "..val.b )
				end

				if istable( dat ) then
					prt:SetColor( dat.Color and Color( dat.Color[ 1 ], dat.Color[ 2 ], dat.Color[ 3 ] ) or Color( 255, 255, 255 ) )
				else
					local var = GetConVar( "xdews_pr_color" ):GetString()
					var = string.Explode( " ", var )
					for i=1, 3 do
						if !var[ i ] then var[ i ] = 255 end
						var[ i ] = tonumber( var[ i ] )
						if !isnumber( var[ i ] ) then var[ i ] = 255 end
						var[ i ] = math.Clamp( math.Round( var[ i ] ), 0, 255 )
					end
					var = Color( var[ 1 ], var[ 2 ], var[ 3 ] )
					prt:SetColor( var )
				end

				local val = prt:GetColor()
				frm.T_Data[ "Color" ] = Vector( val.r, val.g, val.b )
			end },
			{ nil, 48, function( pan, frm, dat )
				local ww, hh = pan:GetSize()
				local str = language.GetPhrase( "xdews."..( istable( dat ) and "M_Edit" or "M_Active" ) )
				local but = xdews.gui_button( pan, ww/2 -256/2, 2, 256, 44, str )
				function but:DoClick2()
					frm:DoSave()
				end
			end },
		}
		surface.PlaySound( "ui/hint.wav" )

		if IsValid( xdews.frame_cur ) then
			xdews.frame_cur:Remove()
		end

		local edit = istable( old )

		local title = language.GetPhrase( edit and "xdews.M_EditPillar" or "xdews.M_SetupPillar" )
		if plate then
			title = language.GetPhrase( edit and "xdews.M_EditPlate" or "xdews.M_SetupPlate" )
			table.remove( configs, 4 )
			table.remove( configs, 4 )
		end

		local hei = 36
		for id, dat in ipairs( configs ) do
			hei = hei +4 +dat[ 2 ]
		end

		local w = 400
		local frame = xdews.gui_frame( title, w, hei )
		xdews.frame_cur = frame

		frame.E_Target = ent
		frame.B_Plate = isbool( plate ) and plate or false
		frame.B_Edit = edit

		local tnk = frame.Think
		function frame:Think()
			tnk( frame )
			local ent = frame.E_Target
			if !IsValid( ent ) or frame.B_Edit != ent:GetActivated() then
				frame:DoClose()
			end
		end
		
		frame.T_Data = {}
		function frame:DoSave()
			local ent = frame.E_Target
			if !IsValid( ent ) or frame.B_Edit != ent:GetActivated() then return end
			frame.T_Data.Entity = ent:EntIndex()
			frame.T_Data.Edit = frame.B_Edit

			net.Start( "xdews_command" )
			net.WriteString( "setup" )
			net.WriteString( util.TableToJSON( frame.T_Data ) )
			net.SendToServer()
			frame:DoClose()
		end

		local hei = 36
		local sty = xdews.stys
		for id, dat in ipairs( configs ) do
			local pan = xdews.gui_panel( frame, 4, hei, w-8, dat[ 2 ], false )

			if dat[ 1 ] and dat[ 1 ] != "" then
				local cc = sty[ "Text" ].r..","..sty[ "Text" ].g..","..sty[ "Text" ].b
				local mk = markup.Parse( "<font=xdews_Font1><color="..cc..">"..language.GetPhrase( dat[ 1 ] ).."</color></font>", w/2 )
				function pan:Paint2( w, h )
					surface.SetDrawColor( sty[ "Panel" ] )
					surface.DrawRect( 0, 0, w, h )
					mk:Draw( 4, h/2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255 )
					//draw.SimpleText( dat[ 1 ], "xdews_Font1", 4, h/2, sty[ "Text" ], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				end
			end
			
			if dat[ 3 ] then
				dat[ 3 ]( pan, frame, old )
			end
			
			hei = hei +4 +dat[ 2 ]
		end

		return frame
	end

	function xdews.menu_select( ent ) // 选择传送位置
		if IsValid( xdews.frame_select ) then
			xdews.frame_select:Remove()
		end
		surface.PlaySound( "ui/hint.wav" )
		
		local frame = xdews.gui_frame( language.GetPhrase( "xdews.M_Select" ), 750, 500, 300, GetConVar( "xdews_pr_fold" ):GetBool() )
		xdews.frame_select = frame

		function frame:OnFold( fold )
			RunConsoleCommand( "xdews_pr_fold", fold and "1" or "0" )
		end

		frame.E_Target = ent
		frame.S_Detail = ""
		frame.T_Details = {}
		frame.T_Locations = {}

		frame.S_Name = "..."
		frame.S_Info = ""
		frame.V_Pos = nil
		frame.A_Ang = Angle()
		frame.N_Auto = 0

		function frame:GetDetail( uid )
			if frame.S_Detail == uid then return end
			frame.S_Detail = uid
			if !frame.T_Details[ uid ] then
				net.Start( "xdews_command" )
				net.WriteString( "detail" )
				net.WriteString( util.TableToJSON( { uid } ) )
				net.SendToServer()
				frame.V_Pos = nil
			else
				frame:UpdateDetail( uid, frame.T_Details[ uid ] )
			end
		end

		function frame:UpdateDetail( uid, dat )
			frame.T_Details[ uid ] = dat
			if frame.S_Detail != uid then return end
			frame.S_Name = dat[ 2 ]
			frame.S_Info = dat[ 3 ]
			frame.V_Pos = Vector( dat[ 4 ][ 1 ], dat[ 4 ][ 2 ], dat[ 4 ][ 3 ] + 36 )
			frame.A_Ang = Angle( 0, math.random( 0, 360 ), 0 )
			frame.N_Reading = SysTime() +0.25

			local str = "<font=xdews_Font1><color=255,255,255>"..frame.S_Info.."</color></font>"
			frame.S_Markup = markup.Parse( str, 442 )
			frame.N_Auto = 0
		end

		local sty = xdews.stys

		// 左上 - 位置搜索
		if true then
			local prt = xdews.gui_panel( frame, 4, 36, 292, 42, true )

			local ww, hh = prt:GetSize()
			local prt, ent = xdews.gui_entry( prt, 2, 2, ww-4, hh-4, "", 32, language.GetPhrase( "xdews.M_Search" ) )
			function prt:OnChange( val )
				timer.Create( "xdews_search", 0.1, 1, function()
					if !IsValid( frame ) or !frame.T_Locations then return end
					for k, v in ipairs( frame.T_Locations ) do
						local show = true
						if val != "" and !string.find( v.S_Name, val ) then
							show = false
						end
						v:SetVisible( show )
					end
				end )
			end
		end

		// 左下 - 位置选择
		if true then
			local prt = xdews.gui_panel( frame, 4, 82, 292, 414, true )

			local ww, hh = prt:GetSize()
			local scr = prt:Add( "DScrollPanel" )
			scr:SetPos( 2, 2 )
			scr:SetSize( ww-4, hh-4 )

			local function AddButton( cls, ico )
				for k, v in ipairs( ents.FindByClass( cls ) ) do
					if !IsValid( v ) or !v.GetActivated or !v:GetActivated() or v:GetUID() == "" then continue end
					if !xdews.pl_sure( nil, v ) then continue end
					local ic2 = string.EndsWith( v:GetNick(), "!!!!!!" ) and xdews.mats[ "Woah" ] or ico

					local but = xdews.gui_button( scr, 0, 0, 0, 32, v:GetNick(), ic2, "xdews_Font1" )
					but:Dock( TOP )
					but:DockMargin( 0, 0, 0, 4 )
					table.insert( frame.T_Locations, but )
						
					but.B_Lock = ( v == frame.E_Target )
					but.S_Name = v:GetNick()
					but.S_UID = v:GetUID()
					but.C_Color = xdews.color_mul( v:GetRColor(), 0.6 )

					if but.B_Lock then
						frame:GetDetail( but.S_UID )
					end
					function but:OnCursor( inn )
						if inn then frame:GetDetail( but.S_UID ) end
					end

					function but:DoClick2()
						net.Start( "xdews_command" )
						net.WriteString( "teleport" )
						net.WriteString( util.TableToJSON( { IsValid( ent ) and ent:EntIndex() or -1, but.S_UID } ) )
						net.SendToServer()
						frame:DoClose()
					end
				end
			end

			AddButton( "sent_xdews_plate", xdews.mats[ "Plate" ] )
			AddButton( "sent_xdews_pillar", xdews.mats[ "Pillar" ] )
		end

		// 右上 - 位置标题
		if true then
			local prt = xdews.gui_panel( frame, 300, 36, 446, 42, true )
			function prt:Paint2( w, h )
				draw.SimpleText( frame.S_Name, "xdews_Font2", 6, h/2, sty[ "Text" ], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			end
		end

		// 右中 - 监视器
		if true then
			local prt = xdews.gui_panel( frame, 300, 82, 446, 180, true )
			
			function prt:Paint2( w, h )
				local var = GetConVar( "xdews_sv_camera" ):GetBool()
				if !var or !frame.V_Pos or !frame.B_Opened then
					surface.SetDrawColor( sty[ "Entry" ] )
					surface.DrawRect( 2, 2, w-4, h-4 )
					if frame.B_Opened then
						draw.SimpleText( "?", "xdews_Font3", w/2, h/2, sty[ "EntryTxt" ], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
					end
				elseif xdews.cams then
					surface.SetDrawColor( 255, 255, 255 )
					surface.SetMaterial( xdews.cams[ 2 ] )
					surface.DrawTexturedRectRotated( w/2, h/2, ScrW()/4, ScrH()/4, 0 )
				end
			end

			local frm = xdews.gui_panel( frame, 300, 82, 446, 180, false )
			frm:SetCursor( "sizeall" )

			frm.B_Drag = false
			frm.N_PosX = 0
			frm.N_PosY = 0

			function frm:Paint( w, h )
				surface.SetDrawColor( sty[ "Panel" ] )
				surface.DrawOutlinedRect( 0, 0, w, h, 2 )
			end

			function frm:Think()
				if !IsValid( frame ) or !frame.B_Opened then return end
				local xx, yy = frm:CursorPos()
				if !frm.B_Drag then
					if frame.V_Pos and ( xx >= 0 and yy >= 0 and xx <= 446 and yy <= 180 ) and input.IsMouseDown( MOUSE_LEFT ) then
						frm.B_Drag = true
						frm.N_PosX, frm.N_PosY = xx, yy
					end

					if frame.N_Auto <= SysTime() then
						local pit = frame.A_Ang.pitch -math.Clamp( frame.A_Ang.pitch, -FrameTime()*32, FrameTime()*32 )
						frame.A_Ang = Angle( pit, frame.A_Ang.yaw -FrameTime()*8, 0 )
					end
				else
					if !input.IsMouseDown( MOUSE_LEFT ) or !frame.V_Pos then
						frm.B_Drag = false
						frame.N_Auto = SysTime() +3
					else
						local x2, y2 = ( xx -frm.N_PosX ), ( yy -frm.N_PosY )
						if x2 != 0 or y2 != 0 then
							frame.A_Ang = Angle( math.Clamp( frame.A_Ang.pitch +y2/2, -90, 90 ), frame.A_Ang.yaw -x2/2, 0 )
							frm.N_PosX, frm.N_PosY = xx, yy
						end
					end
				end
			end
		end

		// 右下 - 介绍
		if true then
			local prt = xdews.gui_panel( frame, 300, 266, 446, 230, true )
			local str = "<font=xdews_Font1><color=255,255,255></color></font>"
			frame.S_Markup = markup.Parse( str, 442 )

			function prt:Paint2( w, h )
				frame.S_Markup:Draw( 6, 3, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 255 )
			end
		end
		
		return frame
	end

	function xdews.menu_destroy( ent ) // 摧毁石碑
		if !IsValid( ent ) then return end
		if IsValid( xdews.frame_cur ) then
			xdews.frame_cur:Remove()
		end
		surface.PlaySound( "common/warning.wav" )

		local frame = xdews.gui_frame( language.GetPhrase( "xdews.M_DestroyW" ), 600, 170 )
		xdews.frame_cur = frame
		frame.E_Target = ent
		frame.S_UID = ent:GetUID()
		local sty = xdews.stys

		local text = xdews.gui_panel( frame, 4, 34, 592, 64, true )

		local str = language.GetPhrase( "xdews.M_DestroyS" )
		local nam = [["]]..( ent:GetNick() or "???" )..[["]]
		str = string.Replace( str, "%NAME%", nam )

		function text:Paint2( w, h )
			draw.SimpleText( str, "xdews_Font1", w/2, h/2, sty[ "Text" ], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end

		for i=1, 2 do
			local txt = language.GetPhrase( "xdews."..( i == 1 and "M_Cancel" or "M_Delete" ) )
			local but = xdews.gui_button( frame, 204 +( i == 1 and -1 or 1 )*128, 110, 192, 48, txt )
			function but:DoClick2()
				frame:DoClose()
				if i == 1 or !IsValid( ent ) then return end
				net.Start( "xdews_command" )
				net.WriteString( "destroy" )
				net.WriteString( util.TableToJSON( { ent:GetUID() } ) )
				net.SendToServer()
			end
		end

		return frame
	end

	function xdews.menu_password( ent ) // 输入解锁密码
		if IsValid( xdews.frame_cur ) then
			xdews.frame_cur:Remove()
		end
		surface.PlaySound( "common/wpn_denyselect.wav" )

		local frame = xdews.gui_frame( language.GetPhrase( "xdews.M_UnlockW" ), 600, 220 )
		xdews.frame_cur = frame
		frame.E_Target = ent
		frame.S_UID = ent:GetUID()
		local sty = xdews.stys

		local text = xdews.gui_panel( frame, 4, 34, 592, 64, true )

		local str = language.GetPhrase( "xdews.M_UnlockS" )
		local nam = [["]]..( ent:GetNick() or "???" )..[["]]
		str = string.Replace( str, "%NAME%", nam )

		function text:Paint2( w, h )
			draw.SimpleText( str, "xdews_Font1", w/2, h/2, sty[ "Text" ], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end

		local hold = xdews.gui_panel( frame, 4, 34 +68, 592, 48, true )
		local _, entry = xdews.gui_entry( hold, 2, 2, 588, 44, "", 32, language.GetPhrase( "xdews.EnterPass" ) )

		for i=1, 2 do
			local txt = language.GetPhrase( "xdews."..( i == 1 and "M_Cancel" or "M_Unlock" ) )
			local but = xdews.gui_button( frame, 204 +( i == 1 and -1 or 1 )*128, 160, 192, 48, txt )
			function but:DoClick2()
				frame:DoClose()
				if i == 1 or !IsValid( ent ) then return end
				net.Start( "xdews_command" )
				net.WriteString( "password" )
				net.WriteString( util.TableToJSON( { frame.S_UID, entry:GetValue() } ) )
				net.SendToServer()
			end
		end

		return frame
	end

	xdews.outs = {}

	function xdews.outline_add( ent, col, thk, noz ) // 实体描边
        if !IsValid( ent ) and !istable( ent ) then return end
        if !IsColor( col ) then col = Color( 255, 255, 255 ) end
        if !isnumber( thk ) then thk = 1 else thk = math.max( 0.01, thk ) end
        if !isbool( noz ) then noz = false end
        if !istable( ent ) then ent = { ent } end

        for k, v in ipairs( ent ) do
            if !IsValid( v ) or v.xdews_outl then
                table.remove( ent, k )
                continue
            end
            v.xdews_outl = true
        end
        if #ent <= 0 then return end
        table.insert( xdews.outs, { ent, col, thk, noz } )
    end

    if true then -- 实体描边相关
        xdews.outl, xdews.oute = {
            Material( "pp/copy" ),
            CreateMaterial( "xdews_outl", "UnlitGeneric", {
                [ "$basetexture" ]  = "models/debug/debugwhite",
                [ "$ignorez" ] 		= 1,
                [ "$alphatest" ] 	= 1,	
            } ),
            render.GetScreenEffectTexture( 0 ),
            render.GetScreenEffectTexture( 1 ),
        }, {}

        function xdews.outline_render( dat )
            local scene = render.GetRenderTarget()
            render.CopyRenderTargetToTexture( xdews.outl[ 3 ] )
            local w, h = ScrW(), ScrH()

            render.Clear( 0, 0, 0, 0, true, true )
            render.UpdateRefractTexture()
            render.SetStencilEnable( true )
            cam.IgnoreZ( dat[ 4 ] )

            render.SuppressEngineLighting( true )
            render.SetStencilWriteMask( 0xFF )
            render.SetStencilTestMask( 0xFF )

            render.SetStencilCompareFunction( STENCIL_ALWAYS )
            render.SetStencilFailOperation( STENCIL_KEEP )

            render.SetStencilZFailOperation( STENCIL_REPLACE )
            render.SetStencilPassOperation( STENCIL_REPLACE )

            cam.Start3D()
            render.SetStencilReferenceValue( 1 )
            for k, v in ipairs( dat[ 1 ] ) do
                if !IsValid( v ) or v.xdews_out then continue end
                v.xdews_out = true
                v:DrawModel()
                v.xdews_out, v.xdews_outl = nil, nil
            end
            cam.End3D()

            render.SetStencilCompareFunction( STENCIL_EQUAL )

            cam.Start2D()
            render.SetStencilReferenceValue( 1 )
            surface.SetDrawColor( dat[ 2 ] )
            surface.DrawRect( 0, 0, w, h )
            cam.End2D()

            render.SuppressEngineLighting( false )
            cam.IgnoreZ( false )
            render.SetStencilEnable( false )

            render.CopyRenderTargetToTexture( xdews.outl[ 4 ] )
            render.SetRenderTarget( scene )

            xdews.outl[ 1 ]:SetTexture( "$basetexture", xdews.outl[ 3 ] )
            render.SetMaterial( xdews.outl[ 1 ] )
            render.DrawScreenQuad()

            render.SetStencilEnable( true )
            render.SetStencilReferenceValue( 0 )
            render.SetStencilCompareFunction( STENCIL_EQUAL )

            xdews.outl[ 2 ]:SetTexture( "$basetexture", xdews.outl[ 4 ] )
            render.SetMaterial( xdews.outl[ 2 ] )

            local thk = dat[ 3 ]
            render.DrawScreenQuadEx( -thk, -thk, w, h )
            render.DrawScreenQuadEx( -thk, 0, w, h )
            render.DrawScreenQuadEx( -thk, thk, w, h )
            render.DrawScreenQuadEx( 0, -thk, w, h )
            render.DrawScreenQuadEx( 0, thk, w, h )
            render.DrawScreenQuadEx( thk, -thk, w, h )
            render.DrawScreenQuadEx( thk, 0, w, h )
            render.DrawScreenQuadEx( thk, thk, w, h )
            render.SetStencilEnable( false )
        end
    end

	xdews.cams = {
		GetRenderTarget( "xdews_camrt", ScrW()/2, ScrH()/2 ),
		CreateMaterial( "xdews_cammt2", "UnlitGeneric", {
			[ "$basetexture" ] = "xdews_camrt",
			[ "$translucent" ] = 0, [ "$vertexcolor" ] = 1, [ "$vertexalpha" ] = 0,
		} )
	}

    function xdews.cam_render()
		if !IsValid( xdews.frame_select ) or !xdews.frame_select.V_Pos then return end
		local var = GetConVar( "xdews_sv_camera" ):GetBool()
		if !var then return end
		local frame = xdews.frame_select

		render.PushRenderTarget( xdews.cams[ 1 ] )
		render.OverrideAlphaWriteEnable( false, false )

		render.ClearDepth()
		render.SetBlend( 1 )
		render.SetColorModulation( 1, 1, 1 )
		render.SuppressEngineLighting( false )

		local mdls = {}
		for k, v in ipairs( ents.GetAll() ) do
			if !IsValid( v ) or !v:GetModel() or v:GetNoDraw() or halo.RenderedEntity() == v then continue end
			if !string.EndsWith( v:GetModel(), ".mdl" ) then continue end
			table.insert( mdls, v )
			v:SetNoDraw( true )
		end

		render.RenderView( {
			origin = frame.V_Pos,
			angles = frame.A_Ang or Angle(),
			x = 0, y = 0, w = ScrW(), h = ScrH(),
			drawviewmodel = false,
			bloomtone = false,
			fov = 100,
		} )

		for k, v in ipairs( mdls ) do
			if !IsValid( v ) or !v:GetNoDraw() then continue end
			v:SetNoDraw( false )
		end

		render.SuppressEngineLighting( false )
		render.OverrideAlphaWriteEnable( false )
		render.PopRenderTarget()
    end

    hook.Add( "RenderScene", "xdews_pr", function()
		xdews.cam_render()
    end )

	hook.Add( "PostDrawEffects", "xdews_pde", function()
        if #xdews.outs > 0 then
            for k, v in ipairs( xdews.outs ) do
                if !istable( v ) then continue end
                xdews.outline_render( v )
            end
            xdews.outs = {}
        end
	end )

	xdews.huds = {
		[ "On" ] = false, [ "Anim" ] = 0, [ "Text" ] = "",
		[ "PosX" ] = 0, [ "PosY" ] = 0,
	}

	hook.Add( "HUDPaint", "xdews_hudp", function()
		local ply = LocalPlayer()
		if IsValid( ply ) and ply:Alive() then
			local tel, ani = ply:GetNWBool( "XDEWS_Enter" ), ply:GetNWFloat( "XDEWS_Fade" )
			local use = ply:GetUseEntity()

			if IsValid( use ) and ( use:GetClass() == "sent_xdews_pillar" or use:GetClass() == "sent_xdews_plate" ) then
				local text = "Setup"
				if use:GetActivated() then
					text = xdews.pl_sure( ply, use ) and "Teleport" or "Unlock"
				end

				local pos = use:WorldSpaceCenter():ToScreen()
				local xx, yy = math.Round( pos.x, 1 ), math.Round( pos.y, 1 )

				if !xdews.huds[ "On" ] or xdews.huds[ "Text" ] != text then
					xdews.huds[ "On" ] = true
					xdews.huds[ "Anim" ] = SysTime() +0.2
					xdews.huds[ "Text" ] = text
					xdews.huds[ "PosX" ] = xx
					xdews.huds[ "PosY" ] = yy
				end
				xdews.huds[ "PosX" ] = Lerp( 1, xdews.huds[ "PosX" ], xx )
				xdews.huds[ "PosY" ] = Lerp( 1, xdews.huds[ "PosY" ], yy )
			elseif xdews.huds[ "On" ] then
				xdews.huds[ "On" ] = false
				xdews.huds[ "Anim" ] = SysTime() +0
			end

			if xdews.huds[ "On" ] or xdews.huds[ "Anim" ] > SysTime() then
				local ler = math.max( 0, ( xdews.huds[ "Anim" ] -SysTime() )/0.2 )
				if xdews.huds[ "On" ] then ler = 1-ler end

				surface.SetFont( "xdews_Font2" )
				local key = input.LookupBinding( "+use" )
				key = "[ "..( key and string.upper( key ) or "???" ).." ] "
				local act = language.GetPhrase( "xdews.E_"..xdews.huds[ "Text" ] )

				local xx, yy = xdews.huds[ "PosX" ], xdews.huds[ "PosY" ]
				local ww, hh = surface.GetTextSize( key..act )
				local w1, h1 = surface.GetTextSize( key )

				draw.SimpleTextOutlined( key, "xdews_Font2", xx -ww/2, yy,
				Color( 255, 255, 0, ler*255 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, ler*255 ) )
				draw.SimpleTextOutlined( act, "xdews_Font2", xx -ww/2 +w1, yy,
				Color( 255, 255, 255, ler*255 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, ler*255 ) )
			end

			if GetConVar( "xdews_cl_fade" ):GetBool() and ( tel or ani > CurTime() ) then
				local tim = GetConVar( "xdews_sv_delay" ):GetFloat()/2
				local ler = math.max( 0, ( ani -CurTime() )/tim )
				if tel then ler = 1-ler end
				local col = GetConVar( "xdews_cl_bright" ):GetBool() and Color( 255, 255, 255 ) or Color( 0, 0, 0 )

				surface.SetDrawColor( col.r, col.g, col.b, math.min( 255, 255*ler*1.5 ) )
				surface.SetMaterial( xdews.mats[ GetConVar( "xdews_cl_bright" ):GetBool() and "FadeW" or "Fade" ] )
				surface.DrawTexturedRectRotated( ScrW()/2, ScrH()/2, ScrW(), ScrH(), 0 )
				surface.DrawTexturedRectRotated( ScrW()/2, ScrH()/2, ScrW(), ScrH(), 180 )

				surface.SetDrawColor( col.r, col.g, col.b, 255*ler )
				surface.DrawRect( 0, 0, ScrW(), ScrH() )
			end
		end
	end )

	hook.Add( "PrePlayerDraw", "xdews_ppd", function( ply, flg )
		if IsValid( ply ) and ply:Alive() and GetConVar( "xdews_cl_effect" ):GetBool() then
			local tel, ani = ply:GetNWBool( "XDEWS_Enter" ), ply:GetNWFloat( "XDEWS_Fade" )
			if tel or ani > CurTime() then
				local tim = GetConVar( "xdews_sv_delay" ):GetFloat()/2
				local ler = 1 -math.max( 0, ( ani -CurTime() )/tim )

				if !ply.xdews_overlay or ply.xdews_overlay >= 2 then -- 史中史
					ply.xdews_overlay = 0

					local mii, maa = ply:GetRenderBounds()
					render.SetBlend( 1 )
					render.MaterialOverride()
					render.SetColorModulation( 1, 1, 1 )

					local ang = Angle( 0, 0, 0 ):Up()
					local norA, posA, norB, posB
					if tel then
						norA = ang
						posA = norA:Dot( ply:GetPos() +norA*maa.z*ler )
						norB = -ang
						posB = norB:Dot( ply:GetPos() +norA*maa.z*ler )
					else
						norA = -ang
						posA = norA:Dot( ply:GetPos() -norA*maa.z*ler )
						norB = ang
						posB = norB:Dot( ply:GetPos() -norA*maa.z*ler )
					end

					local clia = render.EnableClipping( true )
					render.PushCustomClipPlane( norA, posA )
					ply:DrawModel()
					render.PopCustomClipPlane()
					render.EnableClipping( clia )

					local col = ply:GetPlayerColor() or Vector( 1, 1, 1 )
					render.SetBlend( math.Clamp( !tel and ler or ( 1-ler )/2, 0, 1 ) )
					render.MaterialOverride( xdews.mats[ "Bright" ] )
					render.SetColorModulation( col.x, col.y, col.z )

					local clib = render.EnableClipping( true )
					render.PushCustomClipPlane( norB, posB )
					ply:DrawModel()
					render.PopCustomClipPlane()
					render.EnableClipping( clib )

					render.SetBlend( 1 )
					render.MaterialOverride()
					render.SetColorModulation( 1, 1, 1 )

					return true
				else
					ply.xdews_overlay = ply.xdews_overlay +1
				end
			end
		end
	end )

	concommand.Add( "xdews", function() // 传送指令
		if !xdews or !GetConVar( "xdews_sv_usecommand" ) or !GetConVar( "xdews_sv_usecommand" ):GetBool() then
			xdews.hint( ply, "#xdews.H_NoCommand", "buttons/button10.wav", 1 )
			return
		end
		local ply = LocalPlayer()
		if !IsValid( ply ) or !ply:Alive() then return end
		xdews.menu_select( ply )
	end )
end

if true then
	local SVConvars = bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER )
	CreateConVar( "xdews_sv_useplate", "1", SVConvars, "", 0, 1 )
	CreateConVar( "xdews_sv_usecommand", "1", SVConvars, "", 0, 1 )
	CreateConVar( "xdews_sv_customsay", "!xdews", SVConvars, "" )
	CreateConVar( "xdews_sv_altpillar", "0", SVConvars, "", 0, 1 )
	CreateConVar( "xdews_sv_godtp", "1", SVConvars, "", 0, 1 )
	CreateConVar( "xdews_sv_camera", "1", SVConvars, "", 0, 1 )
	CreateConVar( "xdews_sv_delay", "0.5", SVConvars, "", 0, 5 )
	CreateConVar( "xdews_sv_coolpillar", "1", SVConvars, "", 0, 600 )
	CreateConVar( "xdews_sv_coolshard", "1", SVConvars, "", 0, 600 )
	CreateConVar( "xdews_sv_platehp", "0", SVConvars, "", 0, 10000 )

	CreateClientConVar( "xdews_cl_fade", "1", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_cl_effect", "1", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_cl_bright", "0", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_cl_glowshard", "1", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_cl_particle", "1", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_cl_header", "1", true, false, "", 0, 1 )

	CreateClientConVar( "xdews_pr_password", "", true, false, "" )
	CreateClientConVar( "xdews_pr_unlocked", "0", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_pr_persist", "1", true, false, "", 0, 1 )
	CreateClientConVar( "xdews_pr_color", "255 255 0", true, false, "" )
	CreateClientConVar( "xdews_pr_fold", "0", true, false, "", 0, 1 )

	xdews.points = {}

	function xdews.hint( ply, txt, snd, typ, dat ) // 发送提示
		if !isstring( txt ) then txt = "" end
		if !isstring( snd ) then snd = "" end
		if !isnumber( typ ) then typ = NOTIFY_GENERIC end
		if !istable( dat ) then dat = {} end
		
		if SERVER then
			net.Start( "xdews_hint" )
			net.WriteString( txt )
			net.WriteString( snd )
			net.WriteFloat( typ )
			net.WriteString( util.TableToJSON( dat ) )
			if IsValid( ply ) then net.Send( ply )
			else net.Broadcast() end
		else
			if string.StartWith( txt, "#" ) then txt = language.GetPhrase( txt ) end
			if #dat > 0 then
				for k, v in ipairs( dat ) do
					txt = string.Replace( txt, "%"..v[ 1 ].."%", v[ 2 ] )
				end
			end
			if txt != "" then notification.AddLegacy( txt, typ, 5 ) end
			if snd != "" then surface.PlaySound( snd ) end
		end
	end

	function xdews.findByUID( uid ) // 根据UID找到石碑
		if !isstring( uid ) or uid == "" then return nil end

		for k, v in ipairs( ents.FindByClass( "sent_xdews_*" ) ) do
			if !IsValid( v ) or !isfunction( v.GetActivated ) then continue end
			if v:GetUID() == uid then return v end
		end

		return nil
	end

	function xdews.pl_sure( ply, ent ) // 判定解锁
		if CLIENT then
			ply = LocalPlayer()
			if IsEntity( ent ) then
				if !ent.GetUID then return false end
				local free = ent.GetFree and ent:GetFree()
				return free or xdews.points[ ent:GetUID() ]
			elseif isstring( ent ) then
				return xdews.points[ ent ]
			end
			return false
		else
			if !IsValid( ply ) or !istable( ply.xdews_unlocks ) then return false end
			if IsEntity( ent ) then
				if !ent.GetUID then return false end
				local free = ent.GetFree and ent:GetFree()
				return free or ply.xdews_unlocks[ ent:GetUID() ]
			elseif isstring( ent ) then
				return ply.xdews_unlocks[ ent ]
			end
			return false
		end
	end

    hook.Add( "PhysgunPickup", "xdews_notool", function( ply, ent )
        if ent:GetClass() == "sent_xdews_pillar" and ent:GetPersist() then return false end
    end )
    hook.Add( "CanTool", "xdews_notool", function( ply, tr, toolname, tool, button )
		local ent = tr.Entity
        if IsValid( ent ) and ent:GetClass() == "sent_xdews_pillar" and ent:GetPersist() then
			if SERVER and IsValid( ply ) and ply:IsAdmin() and toolname == "remover" then
				net.Start( "xdews_command" )
				net.WriteString( "destroy" )
				net.WriteString( util.TableToJSON( { ent:EntIndex() } ) )
				net.Send( ply )
			end
			return false
		end
    end )
    hook.Add( "GravGunPunt", "xdews_notool", function( ply, ent )
        if ent:GetClass() == "sent_xdews_pillar" and ent:GetPersist() then return false end
    end )

	properties.Add( "xdews_edit", { // 编辑石碑
		MenuLabel = "#xdews.Edit",
		Order = 3424,
		MenuIcon = "icon16/building_edit.png",

		Filter = function( self, ent, ply )
			if !IsValid( ent ) or ( ent:GetClass() != "sent_xdews_pillar" and ent:GetClass() != "sent_xdews_plate" ) then return false end
			if !ent:GetActivated() or ent:GetUID() == "" then return false end
			if ( !gamemode.Call( "CanProperty", ply, "xdews_edit", ent ) ) then return false end
			return true
		end,
		Action = function( self, ent )
			self:MsgStart()
				net.WriteEntity( ent )
			self:MsgEnd()
		end,
		Receive = function( self, length, ply )
			local ent = net.ReadEntity()
			if ( !properties.CanBeTargeted( ent, ply ) ) then return end
			if ( !self:Filter( ent, ply ) ) then return end
			if !ent.GetUID then return end
			if ent:GetClass() == "sent_xdews_pillar" and ( !ply:IsAdmin() and game.SinglePlayer() ) then
				xdews.hint( ply, "#xdews.H_AdminEdit", "buttons/button10.wav", 1 )
				return
			end
			if !ent:GetActivated() or ent:GetUID() == "" then return end
			if !xdews.pl_sure( ply, ent ) then
				xdews.hint( ply, "#xdews.H_NeedUnlock", "buttons/button10.wav", 1 )
				return
			end
			if !xdews.points[ ent:GetUID() ] then return end

			net.Start( "xdews_command" )
			net.WriteString( "edit" )
			net.WriteString( util.TableToJSON( { ent:EntIndex(), xdews.points[ ent:GetUID() ] } ) )
			net.Send( ply )
		end 
	} )

	properties.Add( "xdews_destroy", { // 摧毁石碑
		MenuLabel = "#xdews.Destroy",
		Order = 3424 +1,
		MenuIcon = "icon16/building_delete.png",

		Filter = function( self, ent, ply )
			if !IsValid( ent ) or ent:GetClass() != "sent_xdews_pillar" or !ent:GetPersist() then return false end
			if !ent:GetActivated() or ent:GetUID() == "" then return false end
			if ( !gamemode.Call( "CanProperty", ply, "xdews_edit", ent ) ) then return false end
			return true
		end,
		Action = function( self, ent )
			self:MsgStart()
				net.WriteEntity( ent )
			self:MsgEnd()
		end,
		Receive = function( self, length, ply )
			local ent = net.ReadEntity()
			if ( !properties.CanBeTargeted( ent, ply ) ) then return end
			if ( !self:Filter( ent, ply ) ) then return end
			if !ent.GetUID then return end
			if !ply:IsAdmin() and !game.SinglePlayer() then
				xdews.hint( ply, "#xdews.H_AdminDestroy", "buttons/button10.wav", 1 )
				return
			end
			if !ent:GetActivated() or ent:GetUID() == "" then return end

			net.Start( "xdews_command" )
			net.WriteString( "destroy" )
			net.WriteString( util.TableToJSON( { ent:EntIndex() } ) )
			net.Send( ply )
		end 
	} )
end

if SERVER then
	util.AddNetworkString( "xdews_effect" ) // 特效
	util.AddNetworkString( "xdews_gesture" ) // 玩家手势
	util.AddNetworkString( "xdews_hint" ) // 提示
	util.AddNetworkString( "xdews_command" ) // 界面与指令

    hook.Add( "CanProperty", "xdews_notool", function( ply, prp, ent )
		if ent:GetClass() == "sent_xdews_pillar" and ent:GetPersist() then
			if prp != "xdews_edit" and prp != "xdews_destroy" then
				return false
			end
		end
    end )

    hook.Add( "AllowPlayerPickup", "xdews_notool", function( ply, ent )
        if ent:GetClass() == "sent_xdews_pillar" and ent:GetPersist() then return false end
    end )

    hook.Add( "GravGunPickupAllowed", "xdews_notool", function( ply, ent )
        if ent:GetClass() == "sent_xdews_pillar" and ent:GetPersist() then return false end
    end )

	hook.Add( "InitPostEntity", "xdews_ipe", function()
		timer.Simple( 0, function() xdews.pt_load() end )
	end )

	hook.Add( "PostCleanupMap", "xdews_ipe", function()
		timer.Simple( 0, function() xdews.pt_load() end )
	end )

	hook.Add( "EntityTakeDamage", "xdews_etd", function( tar, dmg )
		if dmg:GetDamage() > 0 and IsValid( tar ) and tar:IsPlayer() and tar:Alive() then
			local tel, ani = tar:GetNWBool( "XDEWS_Enter" ), tar:GetNWFloat( "XDEWS_Fade" )
			if GetConVar( "xdews_sv_godtp" ):GetBool() and ( tel or ani > CurTime() ) then
				dmg:ScaleDamage( 0 ) return true
			end
		end
	end )

	hook.Add( "PlayerSay", "xdews_ps", function( ply, txt, tea )
		if IsValid( ply ) and ply:IsPlayer() and ply:Alive() and txt != "" and !tea then
			local cmd = GetConVar( "xdews_sv_customsay" ):GetString()
			local yes = GetConVar( "xdews_sv_usecommand" ):GetBool()
			if yes and cmd != "" and txt == cmd then
				if ply:GetNWFloat( "XDEWS_CoolShard" ) > CurTime() then
					local tim = math.Round( ply:GetNWFloat( "XDEWS_CoolShard" ) -CurTime(), 1 )
					xdews.hint( ply, "#xdews.H_Cooldown", "buttons/button10.wav", 1, { { "TIME", tim } } )
				else
					net.Start( "xdews_command" )
					net.WriteString( "teleport" )
					net.WriteString( util.TableToJSON( { ply:EntIndex() } ) )
					net.Send( ply )
				end
				return ""
			end
		end
	end )

	xdews.loads = {}
	hook.Add( "PlayerInitialSpawn", "xdews_pis", function( ply )
		xdews.loads[ ply ] = true
	end )
	hook.Add( "StartCommand", "xdews_sc", function( ply, cmd )
		if xdews.loads[ ply ] and !cmd:IsForced() then
			xdews.loads[ ply ] = nil
			ply.xdews_unlocks = xdews.pl_load( ply )
		end

		if IsValid( ply.xdews_target ) then
			if !ply:Alive() then
				ply.xdews_target = nil
				ply:SetNWBool( "XDEWS_Enter", false )
				ply:SetNWFloat( "XDEWS_Fade", 0 )
			else
				local cool = ply:GetNWFloat( "XDEWS_Fade" )
				if cool <= CurTime() then
					local tar = ply.xdews_target
					local pos = xdews.findSpace( tar, ply )
					
					if pos then
						ply:SetPos( pos )
						ply:EmitSound( "xdews.Exit" )
						//local ang = Angle( 0, ( tar:GetPos() -pos ):Angle().yaw, 0 )
						//ply:SetEyeAngles( ang )
					end
					ply.xdews_target = nil

					local tim = GetConVar( "xdews_sv_delay" ):GetFloat()/2
					ply:SetNWFloat( "XDEWS_Fade", CurTime() +tim +0.01 )
					ply:SetNWBool( "XDEWS_Enter", false )
				end
			end
		end
	end )

	net.Receive( "xdews_command", function( len, ply )
		if !IsValid( ply ) or len <= 0 then return end
		local cmd = net.ReadString()
		local dat = util.JSONToTable( net.ReadString() )
		if !istable( dat ) then return end

		if cmd == "setup" then // 启动石碑
			if !dat.Entity then return end local eid = tonumber( dat.Entity )
			if !isnumber( eid ) then return end
			local ent = Entity( tonumber( dat.Entity ) )
			local edit = dat.Edit or false
			
			if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
			if !isfunction( ent.GetActivated ) or ( edit != ent:GetActivated() ) or ent:GetUID() == "" then return end
			if ent:GetClass() == "sent_xdews_pillar" and ( !game.SinglePlayer() and !ply:IsAdmin() ) then
				xdews.hint( ply, "#xdews.H_AdminUse", "buttons/button10.wav", 1 )
				return
			end

			if !isstring( dat.Name ) then dat.Name = "" end
			if dat.Name == "" then
				local str = string.Explode( "_", ent:GetClass() )
				str = string.NiceName( str[ #str ] )
				dat.Name = str.." #"..ent:EntIndex()
			end

			local new = {
				[ "Name" ] = dat.Name,
				[ "Info" ] = isstring( dat.Info ) and dat.Info or "",
				[ "Password" ] = isstring( dat.Password ) and dat.Password or "",
				[ "Unlocked" ] = dat.Unlocked,
				[ "Persist" ] = dat.Persist,
				[ "Color" ] = isvector( dat.Color ) and dat.Color or Vector( 0, 0, 0 ),
			}

			if new.Password != "" and dat.Unlocked then
				timer.Simple( 3, function()
					if !IsValid( ply ) then return end
					xdews.hint( ply, "#xdews.H_NoPass", "common/wpn_denyselect.wav", 3 )
				end )
			end

			new.Pos = ent:GetPos() +Vector( 0, 0, ent:OBBMins().z +2 )
			new.Pos = Vector( math.Round( new.Pos.x, 2 ), math.Round( new.Pos.y, 2 ), math.Round( new.Pos.z, 2 ) )
			new.Ang = ent:GetAngles()
			new.Ang = Vector( math.Round( new.Ang.pitch, 2 ), math.Round( new.Ang.yaw, 2 ), math.Round( new.Ang.roll, 2 ) )
			xdews.points[ ent:GetUID() ] = new

			ent:SetActivated( true )
			ent:SetNick( new.Name )
			ent:SetRColor( new.Color )

			if ent:GetClass() == "sent_xdews_pillar" then
				ent:SetFree( new.Unlocked )
				if new.Persist then
					ent:SetPersist( true )
					undo.ReplaceEntity( ent, nil )
					cleanup.ReplaceEntity( ent, nil )
					xdews.pt_save()
				elseif ent:GetPersist() and xdews.points[ ent:GetUID() ] then
					xdews.points[ ent:GetUID() ] = nil
					ent:SetPersist( false )
					xdews.pt_save()
				end
			end

			if !edit then
				xdews.hint( ply, "#xdews.H_Activated", "buttons/button14.wav", 0, { { "NAME", ent:GetNick() } } )
			else
				xdews.hint( ply, "#xdews.H_Edited", "buttons/button14.wav", 0, { { "NAME", ent:GetNick() } } )
			end
		elseif cmd == "detail" then // 获得细节
			if !dat[ 1 ] then return end
			local ent = xdews.findByUID( dat[ 1 ] )

			if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
			if !isfunction( ent.GetActivated ) or !ent:GetActivated() or ent:GetUID() == "" then return end
			if !xdews.points[ ent:GetUID() ] then return end
			if !xdews.pl_sure( ply, ent ) then return end

			local dat = xdews.points[ ent:GetUID() ]
			local con = { ent:GetUID(), dat.Name, dat.Info, dat.Pos, dat.Ang }

			net.Start( "xdews_command" )
			net.WriteString( "detail" )
			net.WriteString( util.TableToJSON( con ) )
			net.Send( ply )
		elseif cmd == "teleport" then // 发起传送
			if !dat[ 1 ] or !dat[ 2 ] then return end
			local frm = Entity( tonumber( dat[ 1 ] ) )
			local tow = xdews.findByUID( dat[ 2 ] )
			if !IsValid( frm ) or !IsValid( tow ) then return end
			if !tow.GetUID or !tow:GetUID() or tow:GetUID() == "" then return end
			if !xdews.pl_sure( ply, tow ) then return end

			local allow = false
			if frm:GetClass() == "weapon_xdews_shard" or ( frm:IsPlayer() and frm == ply ) then
				if frm:IsPlayer() and !GetConVar( "xdews_sv_usecommand" ):GetBool() then return end
				local col = GetConVar( "xdews_sv_coolshard" ):GetFloat()
				if ply:GetNWFloat( "XDEWS_CoolShard" ) > CurTime() then
					local tim = math.Round( ply:GetNWFloat( "XDEWS_CoolShard" ) -CurTime(), 1 )
					xdews.hint( ply, "#xdews.H_Cooldown", "common/wpn_denyselect.wav", 3, { { "TIME", tim } } )
					return
				end
				ply:SetNWFloat( "XDEWS_CoolShard", CurTime() +col )
				allow = true
			elseif frm:GetClass() == "sent_xdews_pillar" or frm:GetClass() == "sent_xdews_plate" then
				if frm:GetClass() == "sent_xdews_plate" and !GetConVar( "xdews_sv_useplate" ):GetBool() then return end
				local col = GetConVar( "xdews_sv_coolpillar" ):GetFloat()
				if ply:GetNWFloat( "XDEWS_CoolPillar" ) > CurTime() then
					local tim = math.Round( ply:GetNWFloat( "XDEWS_CoolPillar" ) -CurTime(), 1 )
					xdews.hint( ply, "#xdews.H_Cooldown", "common/wpn_denyselect.wav", 3, { { "TIME", tim } } )
					return
				end
				ply:SetNWFloat( "XDEWS_CoolPillar", CurTime() +col )
				if !frm:GetActivated() or frm:GetUID() == "" or !xdews.pl_sure( ply, frm ) then return end
				if ply:GetPos():Distance( frm:GetPos() ) > 1024 then return end
				allow = true
			end
			if !allow then return end

			xdews.onward( tow, ply )
		elseif cmd == "password" then // 解锁石碑
			if !dat[ 1 ] or !dat[ 2 ] then return end
			local ent = xdews.findByUID( dat[ 1 ] )

			if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
			if !isfunction( ent.GetActivated ) or !ent:GetActivated() or ent:GetUID() == "" then return end
			if !xdews.points[ ent:GetUID() ] then return end
			local pot = xdews.points[ ent:GetUID() ]

			if !pot.Password or pot.Password == "" or tostring( dat[ 2 ] ) == pot.Password then
				xdews.pl_unlock( ply, ent, true )
			else
				xdews.hint( ply, "#xdews.H_BadPass", "buttons/button10.wav", 1 )
			end
		elseif cmd == "destroy" then // 摧毁石碑
			if !dat[ 1 ] then return end
			local ent = xdews.findByUID( dat[ 1 ] )

			if !IsValid( ent ) or ent:GetClass() != "sent_xdews_pillar" or !ent:GetPersist() then return end
			if !ent:GetActivated() or ent:GetUID() == "" then return end
			if !xdews.points[ ent:GetUID() ] then return end
			
			xdews.points[ ent:GetUID() ] = nil
			xdews.pt_save()
			
			xdews.hint( ply, "#xdews.H_Destroyed", "buttons/button14.wav", 4, { { "NAME", ent:GetNick() } } )
			ent:Destroy()
		end
	end )

	function xdews.onward( tar, ply ) // 前往目标
		local cool = ply:GetNWFloat( "XDEWS_Fade" )
		if cool <= CurTime() +1 and cool > CurTime() then return false end
		local pos = xdews.findSpace( tar, ply )
		if pos == nil then return false end

		ply.xdews_target = tar
		local tim = GetConVar( "xdews_sv_delay" ):GetFloat()/2
		if tim <= 0 then
			ply:SetPos( pos )
			ply:EmitSound( "xdews.Exit" )
			//local ang = Angle( 0, ( tar:GetPos() -pos ):Angle().yaw, 0 )
			//ply:SetEyeAngles( ang )
		else
			ply:SetNWFloat( "XDEWS_Fade", CurTime() +tim +0.01 )
			ply:SetNWBool( "XDEWS_Enter", true )
			ply:EmitSound( "xdews.Enter" )
		end

		return true
	end

	function xdews.findSpace( tar, ply, dis ) // 寻找空位
		if !IsValid( tar ) or !IsValid( ply ) then return nil end
		if !isnumber( dis ) then dis = 128 end

		local max_try = 1024
		local cnt_try = 0
		while cnt_try < max_try do
			cnt_try = cnt_try +1
			local ran = cnt_try == 1 and Vector( 0, 0, 4 ) or VectorRand():GetNormalized()*math.Rand( dis/2, dis )
			ran.z = math.abs( ran.z )
			local rps = tar:GetPos() +ran

			if !util.IsInWorld( rps ) then continue end
			local trc = util.TraceEntity( {
				start = rps,
				endpos = rps,
				filter = ent,
				mask = MASK_PLAYERSOLID,
			}, ply )
			if trc.Hit then continue end

			trc = util.TraceEntity( {
				start = trc.HitPos,
				endpos = trc.HitPos -Vector( 0, 0, dis*4 ),
				filter = ply,
				mask = MASK_PLAYERSOLID,
			}, ply )

			local mii, maa = ply:GetCollisionBounds()
			local pos = trc.HitPos +trc.HitNormal

			//debugoverlay.Box( pos, mii, maa, 3, Color( 255, 255, 255, 64 ) )
			//debugoverlay.Line( pos, tar:GetPos(), 3, Color( 255, 255, 255 ) )
			//debugoverlay.Text( pos, cnt_try.." tries", 3 )

			return trc.HitPos +trc.HitNormal
		end
		return nil
	end

	function xdews.pl_load( ply ) // 读取玩家数据
		if !IsValid( ply ) or !ply.SteamID then return end
		local saved = {}
		if file.IsDir( "xdewaystone/"..game.GetMap(), "DATA" ) then
			local path = "xdewaystone/"..game.GetMap().."/players/"..string.Replace( ply:SteamID(), ":", "_" )..".txt"
			if file.Exists( path, "DATA" ) then
				local con = file.Read( path, "DATA" )
				if con then
					con = util.JSONToTable( con )
					if istable( con ) and istable( con.Points ) then saved = con.Points end
				end
			end
		end

		local dat = {}
		for uid, tbl in pairs( xdews.points ) do
			if uid != "" and istable( tbl ) and ( saved[ uid ] or tbl.Unlocked ) then
				dat[ uid ] = true
			end
		end

		net.Start( "xdews_command" )
		net.WriteString( "load" )
		net.WriteString( util.TableToJSON( dat ) )
		net.Send( ply )

		return dat
	end

	function xdews.pl_save( ply ) // 保存玩家数据
		if !IsValid( ply ) or !istable( ply.xdews_unlocks ) then return end
		local path = "xdewaystone"
		if !file.IsDir( path, "DATA" ) then file.CreateDir( path ) end
		path = path.."/"..game.GetMap()
		if !file.IsDir( path, "DATA" ) then file.CreateDir( path ) end
		path = path.."/players"
		if !file.IsDir( path, "DATA" ) then file.CreateDir( path ) end
		path = path.."/"..string.Replace( ply:SteamID(), ":", "_" )..".txt"

		local tbl = { [ "Name" ] = ply:Nick(), [ "SteamID" ] = ply:SteamID64(), [ "Points" ] = ply.xdews_unlocks }
		file.Write( path, util.TableToJSON( tbl, true ) )
	end

	function xdews.pl_unlock( ply, ent, bypass ) // 玩家解锁石碑
		if !IsValid( ply ) then return end
		if !istable( ply.xdews_unlocks ) then
			ply.xdews_unlocks = xdews.pl_load( ply )
		end

		local uid, nam = "", ""
		if IsEntity( ent ) and isfunction( ent.GetActivated ) and ent:GetActivated() then
			uid, nam = ent:GetUID(), ent:GetNick()
		elseif isstring( ent ) then uid = ent end
		
		if !isstring( uid ) or uid == "" then return end
		if !bypass and xdews.points[ uid ] then
			local pass = xdews.points[ uid ].Password
			if pass and pass != "" then
				net.Start( "xdews_command" )
				net.WriteString( "password" )
				net.WriteString( util.TableToJSON( { uid } ) )
				net.Send( ply )
				return
			end
		end

		if !ply.xdews_unlocks[ uid ] then
			ply.xdews_unlocks[ uid ] = true

			net.Start( "xdews_command" )
			net.WriteString( "unlock" )
			net.WriteString( util.TableToJSON( { uid, nam } ) )
			net.Send( ply )

			if IsValid( ent ) then
				local sca = ent:GetClass() == "sent_xdews_pillar" and 2 or 1
				local eff = { Pos = ent:WorldSpaceCenter(), Nor = ent:GetRColor()/255, Sca = sca, Name = "xdews_unlock" }
				net.Start( "xdews_effect" )
				net.WriteString( util.TableToJSON( eff ) )
				net.Send( ply )
			end

			xdews.pl_save( ply )
		end
	end

	function xdews.pt_load() // 读取地图数据
		local saved = {}
		if file.IsDir( "xdewaystone/"..game.GetMap(), "DATA" ) then
			local path = "xdewaystone/"..game.GetMap().."/points.txt"
			if file.Exists( path, "DATA" ) then
				local con = util.JSONToTable( file.Read( path, "DATA" ) )
				if istable( con ) then saved = con end
			end
		end

		for k, v in ipairs( ents.FindByClass( "sent_xdews_pillar" ) ) do
			if IsValid( v ) and v:GetActivated() and saved[ v:GetUID() ] then
				v:Remove()
			end
		end

		for uid, dat in pairs( saved ) do
			if !isstring( uid ) or !istable( dat ) then continue end
			if !isvector( dat.Pos ) then continue end
			local pil = ents.Create( "sent_xdews_pillar" )
			pil:SetPos( dat.Pos )
			pil:SetAngles( dat.Ang and Angle( dat.Ang[ 1 ], dat.Ang[ 2 ], dat.Ang[ 3 ] ) or Angle() )
			pil:SetActivated( true )
			pil:SetUID( uid )
			pil:SetNick( dat.Name or "" )
			pil:SetRColor( dat.Color and Vector( dat.Color[ 1 ], dat.Color[ 2 ], dat.Color[ 3 ] ) or Vector() )
			pil:SetPersist( true )
			pil:SetFree( dat.Unlocked )
			pil:SetOwner( nil )
			pil:Spawn()
			pil:SetPos( pil:GetPos() -Vector( 0, 0, pil:OBBMins().z +2 ) )
		end

		xdews.points = saved
	end

	function xdews.pt_save() // 保存地图数据
		local path = "xdewaystone"
		if !file.IsDir( path, "DATA" ) then file.CreateDir( path ) end
		path = path.."/"..game.GetMap()
		if !file.IsDir( path, "DATA" ) then file.CreateDir( path ) end
		path = path.."/points.txt"
		
		local dat = {}
		for k, v in ipairs( ents.FindByClass( "sent_xdews_pillar" ) ) do
			if !IsValid( v ) or !v:GetActivated() or !v:GetPersist() or v:GetUID() == "" then continue end
			if !istable( xdews.points[ v:GetUID() ] ) then continue end
			dat[ v:GetUID() ] = xdews.points[ v:GetUID() ]
		end
		file.Write( path, util.TableToJSON( dat, true ) )
	end

	//for k, v in ipairs( player.GetHumans() ) do
		//v.xdews_unlocks = xdews.pl_load( v )
	//end
end

if CLIENT then
	if true then local name = "xdews_unlock" // 解锁石碑特效
		local EFFECT = {}

		function EFFECT:Init( data )
			local ori = data:GetOrigin()
			local nor = data:GetNormal()
			local sca = data:GetScale()
			self:SetRenderBounds( Vector( -16, -16, -16 )*sca, Vector( 16, 16, 16 )*sca )
			self.CL_Emitter = ParticleEmitter( ori )
			local col = Color( nor.x*255, nor.y*255, nor.z*255 )

			self.BeamLife = CurTime() +1
			self.BeamPos = ori
			self.BeamSca = sca
			self.BeamCol = col

			for i=1, 1 do
				local particle = self.CL_Emitter:Add( "particle/particle_glow_04_additive", ori )
				if particle then
					particle:SetVelocity( Vector() )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( 1 )
					particle:SetStartAlpha( 255 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( 16 )
					particle:SetEndSize( 32*sca )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetRoll( math.random( 0, 360 ) )
					particle:SetColor( col.r, col.g, col.b )
					particle:SetCollide( false )
					particle:SetBounce( 0 )
				end
			end

			for i=1, 1 do
				local particle = self.CL_Emitter:Add( "particle/particle_ring_wave_additive", ori )
				if particle then
					particle:SetVelocity( Vector() )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( 0.5 )
					particle:SetStartAlpha( 255 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( 16 )
					particle:SetEndSize( 32*sca )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetRoll( math.random( 0, 360 ) )
					particle:SetColor( col.r, col.g, col.b )
					particle:SetCollide( false )
					particle:SetBounce( 0 )
				end
			end
			
			for i=1, 32*sca do
				local particle = self.CL_Emitter:Add( "particle/particle_glow_05_addnofog", ori )
				if particle then
					particle:SetVelocity( VectorRand():GetNormalized()*math.Rand( 64, 128 )*sca )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( math.Rand( 1, 2 ) )
					particle:SetStartAlpha( 192 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( 3*sca )
					particle:SetEndSize( math.Rand( 3, 6 )*sca )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetRoll( math.random( 0, 360 ) )
					particle:SetRollDelta( math.Rand( -1, 1 ) )
					particle:SetColor( col.r, col.g, col.b )
					particle:SetGravity( VectorRand():GetNormalized()*128 )
					particle:SetAirResistance( 256 )
					particle:SetCollide( false )
					particle:SetBounce( 0 )
				end
			end

			self.CL_Emitter:Finish()

			local lit = DynamicLight( 0 )
			if lit then
				lit.pos = self:WorldSpaceCenter()
				lit.r = col.r
				lit.g = col.g
				lit.b = col.b
				lit.brightness = 1
				lit.decay = 500
				lit.size = 256*sca
				lit.dietime = CurTime() +2
			end
		end

		function EFFECT:Think() return self.BeamLife > CurTime() end

		local Beam = Material( "effects/laser_citadel1" )
		function EFFECT:Render()
			local ler = 1 -math.Clamp( self.BeamLife -CurTime(), 0, 1 )
			local sca = self.BeamSca
			local sta = self.BeamPos
			local fin = self.BeamPos +Vector( 0, 0, 128*sca )
			col = Color( self.BeamCol.r*( 1-ler ), self.BeamCol.g*( 1-ler ), self.BeamCol.b*( 1-ler ) )
			local enp = sta +( fin -sta )*ler
			render.SetMaterial( Beam )
			render.DrawBeam( sta, enp, sca*32*( 1-ler ), CurTime()*10, CurTime()*10 +1, col )
		end

		effects.Register( EFFECT, name )
	end

	if true then local name = "xdews_destroy" // 破坏石碑特效
		local EFFECT = {}
		
		function EFFECT:Init( data )
            local ent = data:GetEntity()
            local nor = data:GetNormal()
            if !IsValid( ent ) or !string.StartWith( ent:GetClass(), "sent_xdews_" ) then return end
            local rmi, rma = ent:GetRenderBounds()
			self:SetRenderBounds( rmi, rma )

            local col = Color( nor.x*255, nor.y*255, nor.z*255 )
            local cmi, cma = ent:OBBMins(), ent:OBBMaxs()
            local cnt = math.max( 4, math.ceil( cmi:Distance( cma )/2 ) )
			
			self.CL_Emitter = ParticleEmitter( ent:WorldSpaceCenter() )

            for i=1, cnt*2 do
                local ori = ent:LocalToWorld( Vector( math.Rand( cmi.x, cma.x ), math.Rand( cmi.y, cma.y ), math.Rand( cmi.z, cma.z ) ) )
                local particle = self.CL_Emitter:Add( "effects/fleck_cement"..math.random( 1, 2 ), ori )
				if particle then
                    local siz = math.Rand( 2, 4 )
					particle:SetVelocity( VectorRand():GetNormalized()*math.Rand( 32, 64 ) +Vector( 0, 0, 64 ) )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( math.Rand( 4, 8 ) )
					particle:SetStartAlpha( 255 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( siz )
					particle:SetEndSize( siz )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetRoll( math.random( 0, 360 ) )
					particle:SetRollDelta( math.Rand( -1, 1 ) )
					particle:SetColor( 255, 255, 255 )
					particle:SetGravity( Vector( 0, 0, -256 ) )
					particle:SetCollide( true )
					particle:SetBounce( math.Rand( 0.3, 0.6 ) )
				end
            end

            for i=1, math.ceil( cnt/2 ) do
                local ori = ent:LocalToWorld( Vector( math.Rand( cmi.x, cma.x ), math.Rand( cmi.y, cma.y ), math.Rand( cmi.z, cma.z ) ) )
                local particle = self.CL_Emitter:Add( "effects/fleck_ash"..math.random( 2, 3 ), ori )
				if particle then
                    local siz = math.Rand( 8, 16 )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( math.Rand( 2, 4 ) )
					particle:SetStartAlpha( 255 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( siz*4 )
					particle:SetEndSize( siz*2 )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetRoll( math.random( 0, 360 ) )
					particle:SetRollDelta( math.Rand( -1, 1 ) )
					particle:SetColor( 255, 255, 255 )
					particle:SetCollide( false )
					particle:SetBounce( 0 )
				end
            end

			for i=1, cnt do
                local ori = ent:LocalToWorld( Vector( math.Rand( cmi.x, cma.x ), math.Rand( cmi.y, cma.y ), math.Rand( cmi.z, cma.z ) ) )
				local particle = self.CL_Emitter:Add( "effects/spark", ori )
				if particle then
					particle:SetVelocity( VectorRand():GetNormalized()*math.Rand( 32, 64 ) +Vector( 0, 0, 32 ) )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( math.Rand( 0.5, 1 ) )
					particle:SetStartAlpha( 192 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( math.Rand( 2, 4 ) )
                    particle:SetStartLength( 4 )
					particle:SetEndSize( 0 )
                    particle:SetEndLength( 4 )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetRoll( math.random( 0, 360 ) )
					particle:SetRollDelta( math.Rand( -1, 1 ) )
                    particle:SetGravity( Vector( 0, 0, -64 ) )
					particle:SetColor( col.r, col.g, col.b )
					particle:SetCollide( true )
					particle:SetBounce( 1 )
				end
            end

			self.CL_Emitter:Finish()

            ent:SetNoDraw( true )
		end

		function EFFECT:Think() return false end
		function EFFECT:Render() end

		effects.Register( EFFECT, name )
	end
end