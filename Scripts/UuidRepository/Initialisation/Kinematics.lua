local dbFile = "$CONTENT_DATA/Kinematics/Database/kinematicsets.kinematicdb"
local config = sm.json.open(dbFile)
local keyUuidMap = {}

for _, setConfig in ipairs(config.kinematicSetList) do
    local set = sm.json.open(setConfig.name)

    for _, k in ipairs(set.kinematicList) do
        keyUuidMap[k.name] = k.uuid
    end
end

sm.uuidRepos.kinematics = UuidRepository.new(keyUuidMap)
