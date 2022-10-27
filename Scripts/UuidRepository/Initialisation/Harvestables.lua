local dbFile = "$CONTENT_DATA/Harvestables/Database/harvestblesets.harvestabledb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setConfig in ipairs(config.harvestableSetList) do
    local set = sm.json.open(setConfig.name)

    for _, h in ipairs(set.harvestableList) do
        keyUuidMap[h.name] = h.uuid
    end
end

sm.uuidRepos.harvestables = UuidRepository.new(keyUuidMap)
