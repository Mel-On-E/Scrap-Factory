---An interface to handle effects for server and client
---@class Effects : ShapeClass
---@field cl EffectsCl
Effects = class(nil)

--------------------
-- #region Server
--------------------

---create a new effect for all clients
---@param self any
---@param params effectParam
function Effects:sv_createEffect(params)
    self.network:sendToClients("cl_createEffect", params)
end

---pauses or starts the effect for all clients that belongs to the key
---@param self any
---@param key string the key/id of the effect
function Effects:sv_toggleEffect(key)
    self.network:sendToClients("cl_toggleEffect", key)
end

-- #endregion

--------------------
-- #region Client
--------------------

---initialize the Effects system
---@param self any
function Effects.cl_init(self)
    self.cl = self.cl or {}
    self.cl.effects = {}
end

---create an effect for the client
---@param self any
---@param params effectParam parameters for the effect
function Effects.cl_createEffect(self, params)
    local effect = Effects.cl_getEffect(self, params.key)
    if effect then
        effect:destroy()
    end

    effect = sm.effect.createEffect(params.effect, params.host, params.boneName)

    if params.effect == "ShapeRenderable" then
        effect:setParameter("uuid", params.uuid)
        effect:setParameter("color", params.color or sm.color.new(1, 1, 1))
    end

    effect:setScale(params.scale or sm.vec3.one())
    if params.host then
        effect:setOffsetPosition(params.offset or sm.vec3.zero())
    end
    effect:setAutoPlay(params.autoPlay)
    if not params.notStart then
        effect:start()
    end

    self.cl.effects[params.key] = effect
end

---get the effect that belongs to a key
---@param self any
---@param key string the key/id of the effect
---@return Effect|nil effect the effect if it exist or nil
function Effects.cl_getEffect(self, key)
    return self.cl.effects[key]
end

---starts the effect that belongs to a key
---@param self any
---@param key string the key/id of the effect
function Effects.cl_startEffect(self, key)
    return self.cl.effects[key]:start()
end

---pauses or starts the effect that belongs to the key
---@param self any
---@param key string the key/id of the effect
function Effects.cl_toggleEffect(self, key)
    if self.cl.effects[key]:isPlaying() then
        self.cl.effects[key]:stop()
    else
        self.cl.effects[key]:start()
    end
end

---destroy a specific effect
---@param self any
---@param id string id of the effect to destroy
function Effects.cl_destroyEffect(self, id)
    if self.cl.effects[id] then
        self.cl.effects[id]:destroy()
        self.cl.effects[id] = nil
    end
end

---destroy all effects which have been created via the `self` instance
---@param self any
function Effects.cl_destroyAllEffects(self)
    for _, effect in pairs(self.cl.effects) do
        if sm.exists(effect) then
            effect:destroy()
        end
    end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class EffectsCl
---@field effects table<string, Effect>

---@class effectParam
---@field key string key for the effect table
---@field effect string name of the effect
---@field uuid Uuid|nil for ShapeRenderable
---@field color Color|nil for ShapeRenderable
---@field scale Vec3|nil for ShapeRenderable
---@field offset Vec3 offsetPosition (defaults to sm.vec3.zero()) only if a host is defined
---@field host Interactable|Character the host the effect is attached to
---@field boneName string|nil the bone name to attach the effect to
---@field autoPlay boolean|nil if the effect should autoPlay
---@field notStart boolean|nil if the effect should not start immediately

-- #endregion
