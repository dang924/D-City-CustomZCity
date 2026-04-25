local CLASS = player.RegClass("hiddenvip")

function CLASS.Off(self)
    if CLIENT then return end
end

local models = {
    "models/mrduck/sentry/gangs/italian/Male_06_Shirt_Tie.mdl",
}

function CLASS.On(self)
    if CLIENT then return end

    ApplyAppearance(self, nil, nil, nil, true)
    self:SetPlayerColor(Color(10, 10, 100):ToVector())
    self:SetModel(models[math.random(#models)])
    self:SetSubMaterial()

    timer.Simple(0, function()
        if not IsValid(self) then return end
        self:SetBodyGroups("00000000000")
    end)

    local appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    appearance.AAttachments = ""
    appearance.AColthes = ""
    self:SetNetVar("Accessories", "")
    self.CurAppearance = appearance

    -- VIP remains unarmed by game-mode rule (hands only).
    self:SetNWString("PlayerName", "VIP " .. appearance.AName)
end

function CLASS.Guilt(self, victim)
    if CLIENT then return end
    return 1
end
