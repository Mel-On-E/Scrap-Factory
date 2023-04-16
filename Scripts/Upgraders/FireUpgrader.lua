dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---A FireUpgrader that can apply a multiplier to a drop or add a fixed value
---@class FireUpgrader : Upgrader
---@field data FireUpgraderData
FireUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function FireUpgrader:sv_onUpgrade(shape, data)
    data.burning = true

    Upgrader.sv_onUpgrade(self, shape, data)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class FireUpgraderData : UpgraderData
---@field upgrade FireUpgraderUpgrade

---@class FireUpgraderUpgrade : UpgraderUpgrade
---@field multiplier number|nil the multiplier to be applied during an upgrade
---@field add number|nil the amount added to a drop's value during an upgrade

-- #endregion
