dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---A BasicUpgrader that can apply a multiplier to a drop or add a fixed value
---@class BasicUpgrader : Upgrader
---@field data BasicUpgraderData
BasicUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function BasicUpgrader:server_onCreate()
    self.data.upgrade.add = tonumber(self.data.upgrade.add)

    Upgrader.server_onCreate(self, nil)
end

function BasicUpgrader:sv_onUpgrade(shape, data)
    local upgrade = self.data.upgrade

    if upgrade.multiplier then
        data.value = data.value * upgrade.multiplier
    end
    if upgrade.add then
        data.value = data.value + upgrade.add
    end

    Upgrader.sv_onUpgrade(self, shape, data)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class BasicUpgraderData : UpgraderData
---@field upgrade BasicUpgraderUpgrade

---@class BasicUpgraderUpgrade : UpgraderUpgrade
---@field multiplier number|nil the multiplier to be applied during an upgrade
---@field add number|nil the amount added to a drop's value during an upgrade

-- #endregion
