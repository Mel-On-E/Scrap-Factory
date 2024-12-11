---Concentrate the sun's energy to boost solar panels
---@class SolarMirror : ShapeClass
---@field cl SolarMirrorCl
SolarMirror = class(nil)
SolarMirror.sunDir = sm.vec3.new(0.232, 0.688, -0.687):normalize()

local rayLength = 100

--------------------
-- #region Server
--------------------

function SolarMirror:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 23 then
        self:sv_boost_solar_panel()
    end
end

---apply a boost to a solar panel if the ray hits one
function SolarMirror:sv_boost_solar_panel()
    if not isDay() then return end
    if not self:has_valid_rotation() then return end

    local reflectDir = self:get_reflection_dir()
    success, obj = sm.physics.raycast(self.shape.worldPosition, self.shape.worldPosition + reflectDir * rayLength,
        self.shape:getBody())

    if not success then return end

    local length = obj.fraction * rayLength
    self.network:setClientData({ length = length })

    if obj.type ~= "body" then return end

    shape = obj:getShape()
    interactable = shape:getInteractable()
    if not interactable then return end

    publicData = interactable:getPublicData()
    if not publicData or not publicData.boost then return end

    publicData.boost = publicData.boost + 40
end

-- #endregion

--------------------
-- #region Client
--------------------

function SolarMirror:client_onCreate()
    self.cl = {}
    self.cl.rayLength = rayLength

    self.cl.rayEffect = sm.effect.createEffect("ShapeRenderable")
    self.cl.rayEffect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
    self.cl.rayEffect:setParameter("color", sm.color.new(1, 1, 0.0))
    self.cl.rayEffect:setScale(sm.vec3.new(0.25, 0.25, self.cl.rayLength))
end

function SolarMirror:client_onClientDataUpdate(data)
    self.cl.rayLength = data.length or self.cl.rayLength
end

function SolarMirror:client_onFixedUpdate()
    self:cl_toggleBeam(isDay())
    if isDay() then
        self:cl_toggleBeam(self:has_valid_rotation())
    end
end

function SolarMirror:client_onUpdate(dt)
    if not self.cl then return end

    local reflectDir = self:get_reflection_dir()
    local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), reflectDir)

    self.cl.rayEffect:setScale(sm.vec3.new(0.25, 0.25, self.cl.rayLength))
    self.cl.rayEffect:setPosition(self.shape.worldPosition + (reflectDir * self.cl.rayLength / 2))
    self.cl.rayEffect:setRotation(rot)
end

function SolarMirror:client_onDestroy()
    self.cl.rayEffect:destroy()
end

function SolarMirror:cl_toggleBeam(check)
    if check and not self.cl.rayEffect:isPlaying() then
        self.cl.rayEffect:start()
    elseif not check and self.cl.rayEffect:isPlaying() then
        self.cl.rayEffect:stop()
    end
end

-- #endregion

---gets the direction of the sun's reflection on the mirror
function SolarMirror:get_reflection_dir()
    local mirrorNormal = self.shape.up
    return SolarMirror.sunDir - mirrorNormal * 2 * (SolarMirror.sunDir:dot(mirrorNormal))
end

---check if the reflective side of the mirror is facing the sun
function SolarMirror:has_valid_rotation()
    local degrees = math.deg(angle(self.shape.up, -SolarMirror.sunDir))
    return degrees <= 85
end

--------------------
-- #region Types
--------------------

---@class SolarMirrorCl
---@field rayEffect Effect
---@field length number length of the rayEffect


-- #endregion
