local dbFile = "$CONTENT_DATA/Database/toolset.tooldb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setFile in ipairs(config.toolSetList) do
    local set = sm.json.open(setFile)

    for _, t in ipairs(set.toolList) do
        keyUuidMap[t.name] = t.uuid
    end
end

sm.uuidRepos.tools = UuidRepository.new(keyUuidMap)
