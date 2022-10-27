local setFile = "$CONTENT_DATA/MeleeAttacks/meleeattacks.meleeattackset"
local set = sm.json.open(setFile)
local keyUuidMap = {}

for _, m in ipairs(set.meleeAttacks) do
    keyUuidMap[m.name] = m.uuid
end

sm.uuidRepos.meleeAttacks = UuidRepository.new(keyUuidMap)
