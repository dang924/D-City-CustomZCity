AddCSLuaFile()
local mode = CreateClientConVar("headspeak_mode", "0",true,true, "0 - rotate | 1 - scale | 2 - pos", 0, 2)
local multiplyer = CreateClientConVar("headspeak_multiplier", "50",true,true, "0 - rotate | 1 - scale | 2 - pos")
local vector_normal = Vector(1,1,1)

if CLIENT then
    local lastSent = 0
    local UPDATE_RATE = 0.05
    local plyclass = "player_default"

    function RTN()
        /*if not IsValid(ply) then return  end
        local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if not bone then return  end
		ply:ManipulateBoneAngles( bone, Angle( 0, 0, 0 ) )
        ply:ManipulateBoneScale(bone,vector_normal)
        ply:ManipulateBonePosition(bone,vector_origin)*/
        for _,ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then return  end
            local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
            if not bone then return  end
            ply:ManipulateBoneAngles( bone, Angle( 0, 0, 0 ) )
            ply:ManipulateBoneScale(bone,vector_normal)
            ply:ManipulateBonePosition(bone,vector_origin)
        end
    end
    
    hook.Add("Think","SendVoiceVolume",function()
        if CurTime() - lastSent < UPDATE_RATE then return end
        
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then return end
            local vol = ply:VoiceVolume() * multiplyer:GetFloat()
            if vol == 0 or vol < 0.005 then return  end
            local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
            if not bone then return  end
            if mode:GetInt() == 0 then
			    ply:ManipulateBoneAngles( bone, Angle( 0, vol, 0 ) )
            elseif mode:GetInt() == 1 then
                ply:ManipulateBoneScale(bone,vector_normal*vol)
            elseif mode:GetInt() == 2 then
                ply:ManipulateBonePosition(bone,Vector(vol,vol,0))
            end
        end

    end)

    concommand.Add( "headspeak_reset", function( ply, cmd, args )
        RTN()
    end )

    hook.Add("PopulateToolMenu", "HeadspeakMenu", function()
        spawnmenu.AddToolMenuOption("Utilities", "Headspeak", "HeadspeakMenu", "Settings", "", "", function(panel)
            panel:NumSlider("", "headspeak_mode", 0,2,0)
            panel:Help("0 - Rotation")
            panel:Help("1 - Scaling")
            panel:Help("2 - Y Position")
            panel:Help("")
            panel:NumSlider("Multiplier", "headspeak_multiplier",-100,1000,0)
            panel:CheckBox("Manipulate bones on the server","headspeak_serveronly")
            panel:Help("")
            panel:Button("Reset bones","headspeak_reset")
        end)  
    end)
end