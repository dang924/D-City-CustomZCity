-- ============================================================
-- ZC Arctic Balaclava Appearance Fix v2
-- garrysmod/addons/zc_balaclava/lua/autorun/zc_balaclava.lua
--
-- Убирает disallowinappearance у arctic_balaclava и phoenix_balaclava
-- чтобы они появились в Face-слоте appearance меню.
-- Никакой maleonly логики — маски доступны всем моделям.
-- ============================================================

if not CLIENT then return end

local function PatchBalaclava()
    if not hg or not hg.Accessories then return end

    local function Patch(key)
        local acc = hg.Accessories[key]
        if not acc then return end
        acc.disallowinappearance = nil
        acc.placement = acc.placement or "face"
    end

    Patch("arctic_balaclava")
    Patch("phoenix_balaclava")
end

hook.Add("InitPostEntity", "ZCB_BalaclavaPatch", function()
    PatchBalaclava()
    -- На случай если hg.Accessories загрузится чуть позже
    timer.Simple(1, PatchBalaclava)
    timer.Simple(3, PatchBalaclava)
end)
