---@class UuidRepository This class harbours key => uuid mappings for in-game objects for fast retrieval
---@field registry table<string, string> Internal registry and cache for key => uuid mappings
UuidRepository = class()

---Creates a UuidRepository instance with the given key => uuid mapping
---@param keyUuidMap table<string, string> Key => uuid mapping
---@return UuidRepository
function UuidRepository.new(keyUuidMap)
    local instance = UuidRepository()
    instance.registry = keyUuidMap or {}
    instance.cache = {}

    return instance
end

---Requests the Uuid object of the corresponding key
---@param key string In-game object key
---@return Uuid|nil @`Uuid` if the key exists otherwise `nil`
function UuidRepository:requestUuid(key)
    self.registry[key] = type(self.registry[key]) == "string"
        and sm.uuid.new(self.registry[key]) 
        or nil
    return self.registry[key]
end
