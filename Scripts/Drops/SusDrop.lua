dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---Drop that has 10% chance to be impostor
---@class SusDrop : Drop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
SusDrop = class(Drop)

-- #region Server 
function SusDrop:server_onCreate()
	Drop.server_onCreate(self)

	if math.random(1, 10) ~= 10 then
		return
	end

	local data = self.interactable.publicData
	data.impostor = true

	self.interactable:setPublicData(data)
end

-- #endregion
