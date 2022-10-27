local dbFile = "$CONTENT_DATA/Objects/Database/shapesets.shapedb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setFile in ipairs(config.shapeSetList) do
    local set = sm.json.open(setFile)

    for _, p in ipairs(set.partList) do
        keyUuidMap[p.name] = p.uuid
    end
end

sm.uuidRepos.shapes = UuidRepository.new(keyUuidMap)
