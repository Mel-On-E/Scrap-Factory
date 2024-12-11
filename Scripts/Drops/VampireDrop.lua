dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A VampireDrop is a drop that
---@class VampireDrop : Drop
---@field sv VampireDropSv
VampireDrop = class(Drop)

local suckFraction = 0.8
local suckDelayTime = 3 * 40

--------------------
-- #region Server
--------------------

function VampireDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.sv.suckDelay = 0

    if not self.interactable.publicData then return end

    self.interactable.publicData.vampire = true
    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, sm.vec3.one() * 0.5, sm.vec3.zero(),
        sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.sv.trigger:bindOnEnter("sv_onEnter")
end

function VampireDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    self.sv.suckDelay = self.sv.suckDelay - 1

    if isDay() or isSunrise() or isSunset() then
        sm.effect.playEffect("Fire -medium01_putout", self.shape.worldPosition)

        --create pollution drop
        local smoke = sm.shape.createPart(obj_drop_smoke, self.shape.worldPosition, self.shape.worldRotation)
        local newPublicData = {
            value = 0,
            pollution = self.interactable.publicData.value,
            upgrades = {}
        }
        smoke.interactable:setPublicData(newPublicData)

        --destory drop
        self.shape.interactable.publicData.value = nil
        self.shape:destroyPart(0)
    end
end

function VampireDrop:sv_onEnter(_, results)
    if self.sv.suckDelay > 0 then return end

    for _, drop in ipairs(getDrops(results)) do
        local publicData = drop.interactable.publicData

        if not publicData.vampire and self.sv.suckDelay <= 0 then
            self.sv.suckDelay = suckDelayTime

            local stolenValue = suckFraction * publicData.value
            publicData.value = math.sqrt(publicData.value)
            self.interactable.publicData.value = self.interactable.publicData.value + stolenValue
            drop.color = sm.color.new(drop.color.r * 2, drop.color.g * 2, drop.color.b * 2)

            sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
                pos = drop.worldPosition,
                format = "money",
                value = tostring(stolenValue),
                color = '#880808'
            })

            sm.effect.playEffect("Eat - Munch", drop.worldPosition)
            sm.effect.playEffect("Eat - MunchSound", drop.worldPosition)
        end
    end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class VampireDropSv : DropSv
---@field suckDelay number time until a vampire drop can suck again

-- #endregion
