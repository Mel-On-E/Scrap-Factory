dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A DropPlusPlus is a `Drop` that will become permanently more valueable each time it was dropped
---@class DropPlusPlus : Drop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
DropPlusPlus = class(Drop)

--------------------
-- #region Server
--------------------

function DropPlusPlus:server_onCreate()
    Drop.server_onCreate(self)

    if not self.interactable.publicData then return end

    self.interactable.publicData.value = SaveDataManager.Sv_getData("dropPlusPlus")
    SaveDataManager.Sv_setData("dropPlusPlus", self.interactable.publicData.value + 1)
end

-- #endregion
