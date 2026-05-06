/* Note: All credits go to Cpt. Hazama. I take no credit for this. */
include("entities/sent_vj_l4d_director/init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

local table_insert = table.insert
local table_remove = table.remove

ENT.Infected = {
    {class="npc_vj_l4d2_com_male",chance=1},
    {class="npc_vj_l4d2_com_female",chance=1},
    {class="npc_vj_l4d2_com_m_swamp",chance=4},
    {class="npc_vj_l4d2_com_f_swamp",chance=4},
    {class="npc_vj_l4d2_com_m_rain",chance=5},
    {class="npc_vj_l4d2_com_f_rain",chance=5},
    {class="npc_vj_l4d2_com_m_biker",chance=2},
    {class="npc_vj_l4d2_com_m_formal",chance=2},
    {class="npc_vj_l4d2_com_f_formal",chance=2},
    {class="npc_vj_l4d2_com_m_whispoaks",chance=3},
    {class="npc_vj_l4d_com_m_ceda",chance=15},
    {class="npc_vj_l4d_com_m_clown",chance=20},
    {class="npc_vj_l4d_com_m_mudmen",chance=20},
    {class="npc_vj_l4d_com_m_worker",chance=10},
    {class="npc_vj_l4d_com_m_riot",chance=15},
    {class="npc_vj_l4d_com_m_fallsur",chance=70},
    {class="npc_vj_l4d_com_m_jimmy",chance=100}
}