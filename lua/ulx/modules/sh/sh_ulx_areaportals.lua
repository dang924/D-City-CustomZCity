if not ulx then return end
if CLIENT then return end

local CATEGORY_NAME = "ZCity"

local function ulxAreaportalsOpen(calling_ply, enabled)
    local state = tonumber(enabled) == 1

    if not ZC_AreaPortalsForce or not ZC_AreaPortalsForce.SetEnabled then
        ULib.tsay(calling_ply, "[AreaPortals] Controller is not loaded.")
        return
    end

    local opened = ZC_AreaPortalsForce.SetEnabled(state)

    if state then
        ulx.fancyLogAdmin(calling_ply, "#A enabled forced areaportals open (#i portals opened now)", opened or 0)
    else
        ulx.fancyLogAdmin(calling_ply, "#A disabled forced areaportals open")
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx areaportalsopen", ulxAreaportalsOpen, "!areaportalsopen")
cmd:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "1=enable, 0=disable" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Toggle forced opening of all func_areaportal entities.")
