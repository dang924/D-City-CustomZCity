
local CLASS = player.RegClass("Citizen")

function CLASS.Off(self)
    if CLIENT then return end

end

function CLASS.On(self)
    citizennumber = math.random(10000)
    ApplyAppearance(self,nil,nil,nil,true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AColthes = ""
    self:SetNWString("PlayerName","")
    self:SetPlayerColor(Color(23,31,100):ToVector())
    self:SetNetVar("Accessories", Appearance.AAttachments or "none")
    
    self:SetSubMaterial(4, ThatPlyIsFemale(self) and "models/humans/female/group01/citizen_sheet" or "models/humans/male/group01/citizen_sheet") 
    self:SetSubMaterial(ThatPlyIsFemale(self) and 6 or 5, ThatPlyIsFemale(self) and "models/humans/female/group01/citizen_sheet" or "models/humans/male/group01/citizen_sheet")
    self:SetNWString("PlayerName","#".. citizennumber .." ".. Appearance.AName)
    self.CurAppearance = Appearance
end