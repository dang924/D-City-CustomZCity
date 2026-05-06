Nexus = Nexus or {}

local fontCache = {}
local fontCacheV2 = {}
function Nexus:GetFont(size, dontScale, isBold)
    if not istable(size) then
        size = math.floor(size)

        local name = "Nexus:"..tostring(size)..":"..(dontScale and "Non" or "Scaled")..(isBold and "Bold" or "NonBold")
        if fontCache[name] then return name end
        surface.CreateFont(name, {
            font = "Lato",
            size = dontScale and size or Nexus:Scale(size),
            weight = isBold and 700 or 500,
            extended = true,
            antialias = true,
        })

        fontCache[name] = {size, dontScale, isBold}
        return name
    else
        local data = size
        local size = math.floor(data.size)
        local dontScale = data.dontScale
        local isBold = data.bold
        local name = "NexusV2:"..tostring(size)..":"..(dontScale and "Non" or "Scaled")..(isBold and "Bold" or "NonBold")

        if fontCacheV2[name] then return name end

        surface.CreateFont(name, {
            font = "Lato",
            size = dontScale and size or Nexus:GetScale(size),
            weight = isBold and 700 or 500,
            extended = true,
            antialias = true,
        })

        fontCacheV2[name] = {size, dontScale, isBold}
        return name
    end
end

hook.Add("OnScreenSizeChanged", "Nexus:ScaleFonts", function()
    for name, v in pairs(fontCache) do
        if v[2] then continue end
        surface.CreateFont(name, {
            font = "Lato",
            size = Nexus:Scale(v[1]),
            weight = v[3] and 700 or 500,
            extended = true,
            antialias = true,
        })    
    end

    for fontCacheV2, v in pairs(fontCache) do
        if v[2] then continue end
        surface.CreateFont(name, {
            font = "Lato",
            size = Nexus:GetScale(v[1]),
            weight = v[3] and 700 or 500,
            extended = true,
            antialias = true,
        })    
    end
end)