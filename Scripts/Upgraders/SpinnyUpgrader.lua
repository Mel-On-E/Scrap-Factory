dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---An Upgrader which areaTrigger gets bigger and upgrades more as its angularVelocity increases
---@class SpinnyUpgrader : Upgrader
---@field data SpinnyUpgraderData
---@field cl SpinnyUpgraderCl
SpinnyUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function SpinnyUpgrader:server_onCreate()
    Upgrader.server_onCreate(self, { filters = sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character })
end

function SpinnyUpgrader:server_onFixedUpdate()
    Upgrader.server_onFixedUpdate(self)

    local size, offset = self:get_size_and_offset()
    self.upgradeTrigger:setSize(size / 3.75)
end

function SpinnyUpgrader:sv_onUpgrade(shape, data)
    local upgrade = self.data.upgrade

    if upgrade.multiplier then
        local angular = math.min(self.shape.body.angularVelocity:length(), upgrade.maxSpin)
        local upgradeFraction = angular / upgrade.maxSpin
        data.value = data.value + (data.value * (upgrade.multiplier * upgradeFraction))
    end

    Upgrader.sv_onUpgrade(self, shape, data)

    --skirt effect
    sm.event.sendToInteractable(shape.interactable, "sv_e_addEffect", {
        effect = "ShapeRenderable",
        key = "skirt",
        uuid = obj_skirt_effect,
        scale = sm.vec3.new(1, 0.75, 1),
        host = shape.interactable,
        color = self.shape.color
    })
end

function SpinnyUpgrader:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end

    Upgrader.sv_onEnter(self, trigger, results)

    --attach skirt to players when they touch the upgrader
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        if type(result) ~= "Character" then goto continue end

        local player = result:getPlayer()
        if player then
            Effects.sv_createEffect(self, {
                key = "skirt" .. tostring(player.id),
                effect = "ShapeRenderable",
                host = player.character,
                boneName = "jnt_hips",
                uuid = obj_skirt_effect,
                color = self.shape.color
            })
        end

        ::continue::
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function SpinnyUpgrader:client_onCreate()
    Upgrader.client_onCreate(self)

    self.cl.skirtData = {}

    Effects.cl_init(self)
end

function SpinnyUpgrader:client_onFixedUpdate()
    local size, offset = self:get_size_and_offset()

    self.cl.effect:setScale(size)
    self.cl.effect:setOffsetPosition(offset)
    self.cl.effect:setParameter("color", self.shape.color)

    --update player skirts
    for _, player in ipairs(sm.player.getAllPlayers()) do
        local skirtEffect = Effects.cl_getEffect(self, "skirt" .. tostring(player.id))
        if skirtEffect then
            local skirtData = self.cl.skirtData[player.id] or self:cl_initSkirt(player)
            self:cl_updateSkirtData(skirtData)
        end
    end
end

function SpinnyUpgrader:cl_initSkirt(player)
    self.cl.skirtData[player.id] = {
        dir = sm.vec3.zero(),
        spin = 1,
        player = player
    }
    return self.cl.skirtData[player.id]
end

---@param skirtData skirtData
function SpinnyUpgrader:cl_updateSkirtData(skirtData)
    local character = skirtData.player.character
    if character then
        local dir = character.direction
        dir.z = 0

        local change = angle(dir, skirtData.dir) / 4

        --skirtData.spin = skirtData.spin ^ 0.95 + change
        skirtData.spin = math.max(
            0.8 * skirtData.spin + 0.2 * math.max(math.log(skirtData.spin + 0.5, 2), 0) + change, 1)
        skirtData.dir = dir

        local effectKey = "skirt" .. tonumber(skirtData.player.id)
        local skirtEffect = Effects.cl_getEffect(self, effectKey)

        if skirtEffect and sm.exists(skirtEffect) then
            local scale = skirtData.spin ^ 0.5
            local skirtLength = 1.75
            local length = skirtLength / scale

            skirtEffect:setScale(sm.vec3.new(scale, length, scale))
            skirtEffect:setOffsetPosition(sm.vec3.new(0, -0.075 + (skirtLength - length) * 0.075, 0.025))
            skirtEffect:setParameter("color", self.shape.color)
        end
    end
end

function SpinnyUpgrader:client_onDestroy()
    Effects.cl_destroyAllEffects(self)
end

function SpinnyUpgrader:cl_createEffect(params)
    Effects.cl_createEffect(self, params)
end

-- #endregion

function SpinnyUpgrader:get_size_and_offset()
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)

    local size = sm.vec3.new(self.data.upgrade.sphere.x, self.data.upgrade.sphere.y, self.data.upgrade.sphere.z)
    local speed = math.min(self.shape.body.angularVelocity:length() ^ 0.333, self.data.upgrade.maxSpin)
    ---@diagnostic disable-next-line: cast-local-type
    size = size * speed + self.shape:getBoundingBox() * 4

    return size, offset
end

--------------------
-- #region Types
--------------------

---@class SpinnyUpgraderData : UpgraderData
---@field upgrade SpinnyUpgraderUpgrade

---@class SpinnyUpgraderUpgrade : UpgraderUpgrade
---@field multiplier number|nil the minimum amount to be added to a drop's value
---@field sphere table
---@field maxSpin number the maximum angular velocity


---@class SpinnyUpgraderCl : UpgraderCl
---@field skirtData table<number, skirtData>

---@class skirtData
---@field dir Vec3
---@field spin number
---@field player Player

-- #endregion
