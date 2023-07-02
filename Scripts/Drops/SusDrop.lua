dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---a SusDop is a Drop that has a chance to be impostor. When selling the impostor, the player will lose money.
---@class SusDrop : Drop
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
	"#ec7578"
}

local susChance = 0.1

--------------------
-- #region Server
--------------------

function SusDrop:server_onCreate()
	Drop.server_onCreate(self)

	if not self.interactable.publicData then return end

	self.shape:setColor(sm.color.new(colors[math.random(1, #colors)]))

	if math.random() <= susChance then
		self.interactable.publicData.impostor = true
		self.shape:setColor(sm.color.new("#c61111"))
	end
end

-- #endregion
