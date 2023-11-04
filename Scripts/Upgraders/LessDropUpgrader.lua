dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---An Upgrader that can upgrades more the less drops you have.
---@class LessDropUpgrader : Upgrader
---@field data BasicUpgraderData
LessDropUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function LessDropUpgrader:sv_onUpgrade(shape, data)
    print(data.value+1000/g_oreCount)
    data.value = data.value + 1000/g_oreCount

    Upgrader.sv_onUpgrade(self, shape, data)
end

-- #endregion
