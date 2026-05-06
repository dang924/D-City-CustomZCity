if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool

function TOOLMODULE.GetImportList()
    local imports = {}

    file.CreateDir("zcity/appearances/")
    local files = file.Find("zcity/appearances/*.json", "DATA")
    for _, fileName in ipairs(files or {}) do
        imports[#imports + 1] = string.StripExtension(fileName)
    end

    table.sort(imports, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return imports
end

function TOOLMODULE.GetPresetImportList()
    local imports = {}

    file.CreateDir("zcity/appearances/presets/")
    local files = file.Find("zcity/appearances/presets/*.json", "DATA")
    for _, fileName in ipairs(files or {}) do
        imports[#imports + 1] = string.StripExtension(fileName)
    end

    table.sort(imports, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return imports
end

function TOOLMODULE.LoadImport(name)
    if not isstring(name) or name == "" then return nil, "missing name" end

    hg.Appearance = hg.Appearance or {}
    name = string.StripExtension(name)

    if isfunction(hg.Appearance.LoadAppearanceFile) then
        local loaded, reason = hg.Appearance.LoadAppearanceFile(name)
        if loaded then
            return TOOLMODULE.NormalizeAppearance(loaded)
        end

        return nil, reason or "load failed"
    end

    local path = "zcity/appearances/" .. name .. ".json"
    if not file.Exists(path, "DATA") then
        return nil, "file not found"
    end

    local loaded = util.JSONToTable(file.Read(path, "DATA") or "")
    if not istable(loaded) then
        return nil, "invalid json"
    end

    return TOOLMODULE.NormalizeAppearance(loaded)
end

function TOOLMODULE.LoadPresetImport(name)
    if not isstring(name) or name == "" then return nil, "missing name" end

    hg.Appearance = hg.Appearance or {}
    name = string.StripExtension(name)

    if isfunction(hg.Appearance.LoadPreset) then
        local loaded = hg.Appearance.LoadPreset(name)
        if istable(loaded) then
            return TOOLMODULE.NormalizeAppearance(loaded)
        end
    end

    local path = "zcity/appearances/presets/" .. name .. ".json"
    if not file.Exists(path, "DATA") then
        return nil, "file not found"
    end

    local loaded = util.JSONToTable(file.Read(path, "DATA") or "")
    if not istable(loaded) then
        return nil, "invalid json"
    end

    return TOOLMODULE.NormalizeAppearance(loaded)
end
