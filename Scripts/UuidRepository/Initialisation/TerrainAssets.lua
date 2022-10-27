local dbFile = "$CONTENT_DATA/Terrain/Database/assetsets.assetdb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setConfig in ipairs(config.assetSetList) do
    local set = sm.json.open(setConfig.assetSet)

    for _, t in ipairs(set.assetListRenderable) do
        keyUuidMap[t.name] = t.uuid
    end
end

sm.uuidRepos.terrainAssets = UuidRepository.new(keyUuidMap)
