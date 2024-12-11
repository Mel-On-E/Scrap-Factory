dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---An Upgrader that can upgrades less when the save file is old.
---@class SavefileUpgrader : Upgrader
---@field data BasicUpgraderData
SaveFileUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function SaveFileUpgrader:sv_onUpgrade(shape, data)
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
