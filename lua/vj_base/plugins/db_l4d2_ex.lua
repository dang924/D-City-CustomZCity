/*--------------------------------------------------
    *** Copyright (c) 2012-2025 by DrVrej, All rights reserved. ***
    No parts of this code or any of its contents may be reproduced, copied, modified or adapted,
    without the prior written consent of the author, unless otherwise indicated for stand-alone materials.
--------------------------------------------------*/
 VJ.AddPlugin("Left 4 Dead 2 SNPCs - Extended", "NPC")

 if SERVER then
    resource.AddWorkshop("1770130953") -- L4D Common Infected SNPCs
    resource.AddWorkshop("2393175267") -- L4D2 Special Infected SNPCs
end

    local spawnCategory = "Left 4 Dead 2"
    VJ.AddCategoryInfo(spawnCategory, {Icon = "vj_base/icons/l4d.png"})

    -- Common Infected
    VJ.AddNPC("Infected (Male)","npc_vj_l4d2_com_male",spawnCategory)
    VJ.AddNPC("Infected (Female)","npc_vj_l4d2_com_female",spawnCategory)
    VJ.AddNPC("Swamp Infected (Male)","npc_vj_l4d2_com_m_swamp",spawnCategory)
    VJ.AddNPC("Swamp Infected (Female)","npc_vj_l4d2_com_f_swamp",spawnCategory)
    VJ.AddNPC("Rain Infected (Male)","npc_vj_l4d2_com_m_rain",spawnCategory)
    VJ.AddNPC("Rain Infected (Female)","npc_vj_l4d2_com_f_rain",spawnCategory)
    VJ.AddNPC("Biker Infected (Male)","npc_vj_l4d2_com_m_biker",spawnCategory)
    VJ.AddNPC("Formal Infected (Male)","npc_vj_l4d2_com_m_formal",spawnCategory)
    VJ.AddNPC("Formal Infected (Female)","npc_vj_l4d2_com_f_formal",spawnCategory)
    VJ.AddNPC("Whispering Oaks Infected (Male)","npc_vj_l4d2_com_m_whispoaks",spawnCategory)

    -- Special Infected
    VJ.AddNPC("Tank (The Sacrifice)","npc_vj_l4d2_tank_sacrifice",spawnCategory)
    VJ.AddNPC("Witch (The Passing)","npc_vj_l4d2_witch_passing",spawnCategory)

    -- Spawners
    VJ.AddNPC("Random Common Infected Spawner","sent_vj_l4d2_cominf_sp",spawnCategory)
    VJ.AddNPC("Random Common Infected","sent_vj_l4d2_cominf",spawnCategory)
    VJ.AddNPC("AI Director","sent_vj_l4d2_director",spawnCategory,true)

    -- Precache Models --
    util.PrecacheModel("models/darkborn/l4d2/common/common_female_formal.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_female_tanktop_jeans.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_female_tanktop_jeans_rain.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_female_tanktop_jeans_swamp.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_female_tanktop_tshirt_skirt.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_female_tanktop_tshirt_skirt_swamp.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_dressshirt_jeans.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_formal.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_polo_jeans.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_jeans.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_jeans_swamp.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_overalls.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_overalls_rain.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_overalls_swamp.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_cargos.mdl")
    util.PrecacheModel("models/darkborn/l4d2/common/common_male_tanktop_cargos_swamp.mdl")
    util.PrecacheModel("models/darkborn/l4d2/hulk_dlc3.mdl")
    util.PrecacheModel("models/darkborn/l4d2/witch_bride.mdl")