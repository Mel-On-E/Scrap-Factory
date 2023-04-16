dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---Drop that has 10% chance to be impostor
---@class SusDrop : Drop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
SusDrop = class(Drop)
local colors = {
	"#132ed2",
	"#11802d",
	"#ee54bb",
	"#f07d0d",
	"#f6f657",
	"#3f474e",
	"#d7e1f1",
	"#6b2fbc",
	"#71491e",
	"#38e2dd",
	"#50f039",
	"#6b2b3c",
	"#ecc0d3",
	"#fffebe",
	"#708496",
	"#928776",
	"#ec7578",
}
-- #region Server
function SusDrop:server_onCreate()
	Drop.server_onCreate(self)

	self.shape:setColor(sm.color.new(colors[math.random(1, #colors)]))

	if math.random(1, 10) ~= 10 then
		return
	end

	local data = self.interactable.publicData
	data.impostor = true

	self.interactable:setPublicData(data)
	self.shape:setColor(sm.color.new("#c61111"))
end

-- #endregion
