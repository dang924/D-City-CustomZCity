if not ulx then return end
if CLIENT then return end

local CATEGORY_NAME = "ZCity"

local function ulxShopToggle(calling_ply)
    if not ZC_ToggleShop then
        ULib.tsay(calling_ply, "[Shop] Buy menu not loaded.")
        return
    end

    local state = ZC_ToggleShop(calling_ply)
    ulx.fancyLogAdmin(calling_ply, "#A toggled the buy shop: " .. state)
end

local cmd = ulx.command(CATEGORY_NAME, "ulx shoptoggle", ulxShopToggle, "!shoptoggle")
cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
cmd:help("Toggle the buy shop on or off for all players.")
