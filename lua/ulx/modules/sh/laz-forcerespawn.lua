
CATEGORY_NAME = "Laz-Cmds"
print( "[LazMod] Laz-ForceRespawn.lua loaded.")

Laz = Laz or {}
Laz.ForceRespawn = Laz.ForceRespawn or {}


local cvarForceRespawnTime = CreateConVar('lm_frespawn_time', "0", FCVAR_ARCHIVE+FCVAR_SERVER_CAN_EXECUTE+FCVAR_NOTIFY, "If set above 0, this will auto force player to respawn after a specified time. 0=Disable / set time in second",0,3600)
local cvarForceRespawnAtDeath = CreateConVar('lm_frespawn_atdeath', "0", FCVAR_ARCHIVE+FCVAR_SERVER_CAN_EXECUTE+FCVAR_NOTIFY, "Should player auto force respawn at where he died. 0=Disable / 1=Enable",0,1)

function Laz.ForceRespawn.Cmd( calling_ply, target_plys, atDeath )
	local affected_plys = {}
		
	for i=1, #target_plys do
		local ply = target_plys[ i ]
		
		if ply:Alive() then
			ULib.tsayError(calling_ply, "[ForceRespawn] Player "..ply:Name().." is not dead.")
			continue
		end

		ply:Spawn()

		table.insert( affected_plys, ply )

		if atDeath and ply.fspnPos then
			ply:SetPos( ply.fspnPos )
			ply:SetEyeAngles( calling_ply:GetAngles() )
			ply:SetLocalVelocity( Vector( 0, 0, 0 ) )
		end

	end

	ulx.fancyLogAdmin( calling_ply, "#A force respawned #T.", affected_plys )
end
local frespawn = ulx.command( CATEGORY_NAME, "ulx frespawn", Laz.ForceRespawn.Cmd, "!frespawn" )
frespawn:addParam{ type=ULib.cmds.PlayersArg }
frespawn:addParam{ type=ULib.cmds.BoolArg, default=false, hint="At where he died", ULib.cmds.optional }
frespawn:defaultAccess( ULib.ACCESS_ADMIN )
frespawn:help( "Force respawn player." )

if CLIENT then return end

hook.Add("PlayerDeath", "Laz.ForceRespawn.PlyDeath", function( victim, inflictor, attacker )
	victim.fspnPos = victim:GetPos()

	if cvarForceRespawnTime:GetFloat() <= 0 then return end

	timer.Create( "LMFSPN-"..victim:SteamID(), cvarForceRespawnTime:GetFloat(), 1, function()
		if !victim:Alive() then
			victim:Spawn()
			if !cvarForceRespawnAtDeath:GetBool() then return end
			victim:SetPos(victim.fspnPos)
		end
	end)
end)

hook.Add("PlayerSpawn", "Laz.ForceRespawn.PlySpawn", function( ply )

	if !timer.Exists( "LMFSPN-"..ply:SteamID() ) then return end
	timer.Remove( "LMFSPN-"..ply:SteamID() )

end)

hook.Add("PlayerSpawnAsSpectator", "Laz.ForceRespawn.PlySpawnSpec", function( ply )

	if !timer.Exists( "LMFSPN-"..ply:SteamID() ) then return end
	timer.Remove( "LMFSPN-"..ply:SteamID() )

end)

hook.Add("PlayerDisconnected", "Laz.ForceRespawn.PlyDisconn", function( ply )

	if !timer.Exists( "LMFSPN-"..ply:SteamID() ) then return end
	timer.Remove( "LMFSPN-"..ply:SteamID() )

end)
