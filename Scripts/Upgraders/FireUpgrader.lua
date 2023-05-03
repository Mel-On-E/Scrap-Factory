dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---A FireUpgrader upgrade drops, but sets them on fire. Burning drops will be destroyed after a fixed amount of time and cause pollution.
---@class FireUpgrader : Upgrader
---@field data FireUpgraderData
FireUpgrader = class(Upgrader)

--------------------
-- #region Server
--------------------

function FireUpgrader.server_onCreate(self)
    Upgrader.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "FireUpgraderTutorial")
end

function FireUpgrader:sv_onUpgrade(shape, data)
    if g_drops[tostring(shape.uuid)].flammable then
        data.burning = true
        data.value = data.value + (self.data.upgrade.add or 0)
        data.value = data.value * (self.data.upgrade.multiplier or 1)

        Upgrader.sv_onUpgrade(self, shape, data)
    end
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
