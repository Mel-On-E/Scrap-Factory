dofile("$CONTENT_DATA/Scripts/Drops/RadioactiveDrop.lua")
dofile("$CONTENT_DATA/Scripts/Drops/GasDrop.lua")

---A RadioactiveGasDrop is a Drop that is gaseous and radioactive
---@class RadioactiveGasDrop : RadioactiveDrop
---@field sv GasDropSv
RadioactiveGasDrop = class(RadioactiveDrop)

--------------------
-- #region Server
--------------------

function RadioactiveGasDrop:server_onCreate()
    RadioactiveDrop.server_onCreate(self)
    GasDrop.sv_init(self)
end

function RadioactiveGasDrop:server_onFixedUpdate()
    RadioactiveDrop.server_onFixedUpdate(self)
    GasDrop.sv_applyImpulse(self)
    GasDrop.sv_destroyFarTravelledDrops(self)
end

-- #endregion
