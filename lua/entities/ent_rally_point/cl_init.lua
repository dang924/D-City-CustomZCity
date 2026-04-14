include("shared.lua")

-- When active the server sets NoDraw(true), so this is only reached for the
-- visible/inactive state.  We also skip draw entirely if the server flag says
-- active, as a client-side guard for late NoDraw propagation.
function ENT:Draw()
    if self:GetActive() then return end
    self:DrawModel()
end
