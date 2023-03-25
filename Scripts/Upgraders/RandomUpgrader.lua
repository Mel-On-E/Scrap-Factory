dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---A RandomUpgrader that can apply a random multiplier to a drop or add a random value
---@class RandomUpgrader : Upgrader
---@field data RandomUpgraderData
RandomUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function RandomUpgrader:sv_onUpgrade(shape, data)
    local upgrade = self.data.upgrade

    if upgrade.addMin and upgrade.addMax then
        data.value = data.value + math.random(upgrade.addMin, upgrade.addMax)
    end

    if upgrade.multiplierMin and upgrade.multiplierMax then
        local multiplierRange = upgrade.multiplierMax - upgrade.multiplierMin
        local multiplier = upgrade.multiplierMin + math.random() * multiplierRange
        data.value = data.value * multiplier
    end

    Upgrader.sv_onUpgrade(self, shape, data)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class RandomUpgraderData : UpgraderData
---@field upgrade RandomUpgraderUpgrade

---@class RandomUpgraderUpgrade : UpgraderUpgrade
---@field addMin number|nil the minimum amount to be added to a drop's value
---@field addMax number|nil the maximum amount to be added to a drop's value
---@field multiplierMin number|nil the minimum multiplier to be applied to a drop's value
---@field multiplierMax number|nil the maximum multiplier to be applied to a drop's value

-- #endregion
