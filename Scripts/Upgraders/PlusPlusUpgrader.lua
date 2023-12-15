dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---An Upgrader that can upgrades more the less drops you have.
---@class PlusPlusUpgrader : Upgrader
---@field data BasicUpgraderData
PlusPlusUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function PlusPlusUpgrader:sv_onUpgrade(shape, data)
    local count = SaveDataManager.Sv_getData("upgraderPlusPlus")
    SaveDataManager.Sv_setData("upgraderPlusPlus", count + 1)
    data.value = data.value + count

    Upgrader.sv_onUpgrade(self, shape, data)
end

-- #endregion
