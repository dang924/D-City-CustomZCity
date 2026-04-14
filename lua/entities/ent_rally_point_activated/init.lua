AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Override Initialize: run the base setup then immediately go active.
function ENT:Initialize()
    self.BaseClass.Initialize(self)
    -- Defer one tick so physics has settled before we freeze it.
    timer.Simple(0, function()
        if IsValid(self) then
            self:SetActiveState(true, true)  -- noSave = true, PermaProps owns persistence
        end
    end)
end
