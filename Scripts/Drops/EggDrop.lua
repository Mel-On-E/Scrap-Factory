dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---An EggDrop is a drop that is egg.
---@class EggDrop: Drop
EggDrop = class(Drop)

--------------------
-- #region Server
--------------------

function EggDrop:server_onCreate()
    Drop.server_onCreate(self)
end

-- #endregion

--------------------
-- #region Client
--------------------

function EggDrop:client_onCreate()
    Drop.client_onCreate(self)
end

-- #endregion
