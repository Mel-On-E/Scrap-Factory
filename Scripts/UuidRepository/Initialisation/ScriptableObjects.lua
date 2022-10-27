local dbFile = "$CONTENT_DATA/scriptableObjectSets.sobdb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setConfig in ipairs(config.scriptableObjectSetList) do
    local set = sm.json.open(setConfig.scriptableObjectSet)

    for _, s in ipairs(set.scriptableObjectList) do
        keyUuidMap[s.name] = s.uuid
    end
end

sm.uuidRepos.scriptableObjects = UuidRepository.new(keyUuidMap)
