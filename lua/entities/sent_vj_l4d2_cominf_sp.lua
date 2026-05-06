/*--------------------------------------------------
    *** Copyright (c) 2012-2025 by DrVrej, All rights reserved. ***
    No parts of this code or any of its contents may be reproduced, copied, modified or adapted,
    without the prior written consent of the author, unless otherwise indicated for stand-alone materials.
--------------------------------------------------*/
AddCSLuaFile()

ENT.Base = "obj_vj_spawner_base"
ENT.Type = "anim"
ENT.PrintName = "Random Common Infected Spawner"
ENT.Author = "Darkborn"
ENT.Contact = "http://steamcommunity.com/groups/vrejgaming"
ENT.Category = "VJ Base Spawners"
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if !SERVER then return end

local entsList = {
    "npc_vj_l4d2_com_male",
    "npc_vj_l4d2_com_female",
    "npc_vj_l4d2_com_m_swamp:10",
    "npc_vj_l4d2_com_f_swamp:10",
    "npc_vj_l4d2_com_m_rain:10",
    "npc_vj_l4d2_com_f_rain:10",
    "npc_vj_l4d2_com_m_biker:10",
    "npc_vj_l4d2_com_m_formal:10",
    "npc_vj_l4d2_com_f_formal:10",
    "npc_vj_l4d2_com_f_rain:10",
    "npc_vj_l4d2_com_m_whispoaks:10"
}
ENT.EntitiesToSpawn = {
    {SpawnPosition = Vector(0, 0, 0), Entities = entsList},
    {SpawnPosition = Vector(50, 50, 0), Entities = entsList},
    {SpawnPosition = Vector(50, -50, 0), Entities = entsList},
    {SpawnPosition = Vector(-50, 50, 0), Entities = entsList},
    {SpawnPosition = Vector(-50, -50, 0), Entities = entsList},
}
/*--------------------------------------------------
    *** Copyright (c) 2012-2025 by DrVrej, All rights reserved. ***
    No parts of this code or any of its contents may be reproduced, copied, modified or adapted,
    without the prior written consent of the author, unless otherwise indicated for stand-alone materials.
--------------------------------------------------*/