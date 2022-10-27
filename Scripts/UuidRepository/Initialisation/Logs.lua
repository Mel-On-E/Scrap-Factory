local setFile = "$CONTENT_DATA/Logs/logs.logset"
local set = sm.json.open(setFile)
local keyUuidMap = {}

for _, l in ipairs(set.logList) do
    keyUuidMap[l.name] = l.uuid
end

sm.uuidRepos.logs = UuidRepository.new(keyUuidMap)
