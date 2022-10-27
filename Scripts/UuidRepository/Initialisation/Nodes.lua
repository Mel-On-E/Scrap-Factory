local setFile = "$CONTENT_DATA/Nodes/node.nodeset"
local set = sm.json.open(setFile)
local keyUuidMap = {}

for _, n in ipairs(set.nodeList) do
    keyUuidMap[n.name] = n.uuid
end

sm.uuidRepos.nodes = UuidRepository.new(keyUuidMap)
