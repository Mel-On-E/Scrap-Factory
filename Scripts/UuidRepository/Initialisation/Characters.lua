local dbFile = "$CONTENT_DATA/Characters/Database/charactersets.characterdb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setFile in ipairs(config.characterSetList) do
    local set = sm.json.open(setFile)

    for _, c in ipairs(set.characters) do
        keyUuidMap[c.name] = c.uuid
    end
end

sm.uuidRepos.characters = UuidRepository.new(keyUuidMap)
