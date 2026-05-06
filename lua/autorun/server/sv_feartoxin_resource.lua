if not SERVER then return end

local files = file.Find("sound/feartoxin/*.mp3", "GAME")
for _, name in ipairs(files or {}) do
    resource.AddFile("sound/feartoxin/" .. name)
end
