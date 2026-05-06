include("vj_base/extensions/l4d_com_infected.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
/*-----------------------------------------------
    *** Copyright (c) 2012-2025 by DrVrej, All rights reserved. ***
    No parts of this code or any of its contents may be reproduced, copied, modified or adapted,
    without the prior written consent of the author, unless otherwise indicated for stand-alone materials.
-----------------------------------------------*/
ENT.Model = "models/darkborn/l4d2/common/common_male_polo_jeans.mdl"
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:Zombie_OnInit()
    self:SetBodygroup(0,math.random(0,1))
    self:SetBodygroup(1,math.random(0,3))
    self:SetSkin(math.random(0,3))
end
/*-----------------------------------------------
    *** Copyright (c) 2012-2025 by DrVrej, All rights reserved. ***
    No parts of this code or any of its contents may be reproduced, copied, modified or adapted,
    without the prior written consent of the author, unless otherwise indicated for stand-alone materials.
-----------------------------------------------*/

