-- Thin autorun bootstrap for reorganized ZC feature modules.
-- Keeps load order deterministic while moving gameplay files out of autorun/*.

local function collectLuaFiles(baseDir)
    local out = {}

    local function walk(dir)
        local files, dirs = file.Find(dir .. "/*", "LUA")
        table.sort(files)
        table.sort(dirs)

        for _, f in ipairs(files) do
            if string.EndsWith(f, ".lua") then
                table.insert(out, dir .. "/" .. f)
            end
        end

        for _, d in ipairs(dirs) do
            walk(dir .. "/" .. d)
        end
    end

    walk(baseDir)
    return out
end

local roots = {
    shared = "zc_features/shared",
    server = "zc_features/server",
    client = "zc_features/client",
}

local sharedFiles = collectLuaFiles(roots.shared)
local serverFiles = collectLuaFiles(roots.server)
local clientFiles = collectLuaFiles(roots.client)

if SERVER then
    for _, p in ipairs(sharedFiles) do
        AddCSLuaFile(p)
    end
    for _, p in ipairs(clientFiles) do
        AddCSLuaFile(p)
    end

    for _, p in ipairs(sharedFiles) do
        include(p)
    end
    for _, p in ipairs(serverFiles) do
        include(p)
    end

    print("[ZC Bootstrap] Loaded shared=" .. tostring(#sharedFiles) .. " server=" .. tostring(#serverFiles) .. " client-sent=" .. tostring(#clientFiles))
    return
end

for _, p in ipairs(sharedFiles) do
    include(p)
end
for _, p in ipairs(clientFiles) do
    include(p)
end

print("[ZC Bootstrap] Loaded shared=" .. tostring(#sharedFiles) .. " client=" .. tostring(#clientFiles))
