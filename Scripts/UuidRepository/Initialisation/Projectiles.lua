local setFile = "$CONTENT_DATA/Projectiles/projectiles.projectileset"
local set = sm.json.open(setFile)
local keyUuidMap = {}

for _, p in ipairs(set.projectiles) do
    keyUuidMap[p.name] = p.uuid
end

sm.uuidRepos.projectiles = UuidRepository.new(keyUuidMap)
