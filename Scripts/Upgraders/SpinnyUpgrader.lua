dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---An Upgrader which areaTrigger gets bigger and upgrades more as its angularVelocity increases
---@class SpinnyUpgrader : Upgrader
---@field data SpinnyUpgraderData
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
        scale = sm.vec3.new(1, 0.75, 1)
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
            sm.event.sendToPlayer(player, "sv_e_createEffect", {
                id = "skirt" .. tostring(player.id),
                effect = "ShapeRenderable",
                host = player.character,
                name = "jnt_hips",
                uuid = obj_skirt_effect,
                start = true
            })
        end

        ::continue::
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function SpinnyUpgrader:client_onFixedUpdate()
    local size, offset = self:get_size_and_offset()

    self.cl.effect:setScale(size)
    self.cl.effect:setOffsetPosition(offset)
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
---@field maxSpin number the maximum angular


-- #endregion
