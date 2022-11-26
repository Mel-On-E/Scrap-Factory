dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---@class RandomUpgrader : Upgrader
SpinnyUpgrader = class(Upgrader)

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

    sm.event.sendToInteractable(shape.interactable, "sv_e_addEffect", {
        effect = "ShapeRenderable",
        key = "skirt",
        uuid = obj_skirt_effect,
        scale = sm.vec3.new(1, 0.75, 1)
    })

    Upgrader.sv_onUpgrade(self, shape, data)
end

function SpinnyUpgrader:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end
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

    Upgrader.sv_onEnter(self, trigger, results)
end

function SpinnyUpgrader:client_onFixedUpdate()
    local size, offset = self:get_size_and_offset()

    self.cl.effect:setScale(size)
    self.cl.effect:setOffsetPosition(offset)
end

function SpinnyUpgrader:get_size_and_offset()
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)

    local size = sm.vec3.new(self.data.upgrade.sphere.x, self.data.upgrade.sphere.y, self.data.upgrade.sphere.z)
    local speed = math.min(self.shape.body.angularVelocity:length() ^ 0.333, self.data.upgrade.maxSpin)
    size = size * speed + self.shape:getBoundingBox() * 4

    return size, offset
end
