local CLASS = player.RegClass("scientist")

function CLASS.Off(self)
    if CLIENT then return end
end
local prefix = {"Бакалавр","Специалист","Магистр","Аспирант","Иследователь","Доктор","Мистер"}
local models = {
    "models/bmscientistcits/p_male_01.mdl",
    "models/bmscientistcits/p_male_02.mdl",
    "models/bmscientistcits/p_male_03.mdl",
    "models/bmscientistcits/p_male_04.mdl",
    "models/bmscientistcits/p_male_05.mdl",
    "models/bmscientistcits/p_male_06.mdl",
    "models/bmscientistcits/p_male_07.mdl",
    "models/bmscientistcits/p_male_08.mdl",
    "models/bmscientistcits/p_male_09.mdl",
    "models/bmscientistcits/p_male_10.mdl",
}

function CLASS.On(self)
    if CLIENT then return end
    ApplyAppearance(self,nil,nil,nil,true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    self:SetNWString("PlayerName","")
    self:SetPlayerColor(Color(255,255,255):ToVector())
    self:SetModel(models[math.random(#models)])
    Appearance.AAttachments = "none"
    self:SetNetVar("Accessories", Appearance.AAttachments or "none")

    self:SetSubMaterial()
    Appearance.AColthes = ""
    self:SetNWString("PlayerName", prefix[math.random(#prefix)] .." ".. Appearance.AName )
    self.CurAppearance = Appearance
end