dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A FortuneWheelFurnace has a bunch of rotating areas that like do different stuff.
---@class FortuneWheelFurnace : Furnace
---@field sv FortuneWheelFurnaceSv
---@field cl FortuneWheelFurnaceCl
FortuneWheelFurnace = class(Furnace)

local UPGRADES = {
	function(value) return value * 0.1 end,
	function(value) return value * 2 end,
	function(value) return value * 0 end,
	function(value) return value * 16 end,
	function(value) return value * 8 end,
	function(value) return value * 0.5 end,
	function(value) return value * 4 end,
	function(value) return value * 1 end,
}


local upgradeSize = sm.vec3.new(0.25, 0.0416667, 1.5 * 1.5)

local function updateAngle(angle, time)
	local speed = 69.0 * 3 -- Adjust this value to change the speed of movement
	return angle + speed * time
end

local function moveObjectInCircle(self, angle)
	local radius = upgradeSize.x * 6 / 2 - 0.125

	-- Calculate the new position of the object using polar coordinates
	local x = radius * math.cos(math.rad(angle))
	local y = radius * math.sin(math.rad(angle))

	-- Ensure the object stays within the box
	x = math.max(-radius, math.min(radius, x))
	y = math.max(-radius, math.min(radius, y))

	-- Update the object's position
	return sm.vec3.new(x, self.data.offset.y, y)
end

local function getUpgradeSize(self)
	local size = sm.vec3.new(self.data.box.x, self.data.box.y * 7.5, self.data.box.z)
	size.x = size.x * 2.5 / #UPGRADES
	size.y = size.y * 2.5 / #UPGRADES
	return size
end

--------------------
-- #region Server
--------------------

function FortuneWheelFurnace:server_onCreate()
	Furnace.server_onCreate(self, {})

	self.sv.angle = 0
end

function FortuneWheelFurnace:sv_onEnter(_, results)
	if not self.powerUtil.active then return end

	for _, drop in ipairs(getDrops(results)) do
		drop.interactable.publicData.value = drop.interactable.publicData.value * 2

		for k, _ in ipairs(UPGRADES) do
			--check if drop is in upgrade areas
			local size = getUpgradeSize(self)
			local angle = (self.sv.angle + (k - 1) * (360 / (#UPGRADES))) % 360
			local offset = moveObjectInCircle(self, angle)
			offset.y = offset.z

			local pos = drop.worldPosition
			local worldPos = self.shape.worldPosition

			if pos.x >= worldPos.x + offset.x - size.x / 2 and pos.x <= worldPos.x + offset.x + size.x / 2
				and pos.y >= worldPos.y + offset.y - size.y / 2 and pos.y <= worldPos.y + offset.y + size.y / 2 then
				drop.interactable.publicData.value = UPGRADES[k](drop.interactable.publicData.value)
				break
			end
		end

		self:sv_onEnterDrop(drop)
	end
end

function FortuneWheelFurnace:server_onFixedUpdate(timeStep)
	Furnace.server_onFixedUpdate(self)

	self.sv.angle = updateAngle(self.sv.angle, timeStep)
end

-- #endregion


--------------------
-- #region Client
--------------------

function FortuneWheelFurnace:client_onCreate()
	Furnace.client_onCreate(self)

	self.cl.upgradeEffects = {}

	local colors = {}
	local spectrumSize = 256 -- Assuming 8-bit color values
	for i = 1, #UPGRADES do
		local r = math.floor((i - 1) * (spectrumSize - 1) / (#UPGRADES - 1))
		local g = math.floor((spectrumSize - 1) / 2)
		local b = spectrumSize - 1 - r

		table.insert(colors, sm.color.new(r / 256, g / 256, b / 256))
	end

	for k, _ in ipairs(UPGRADES) do
		local size = getUpgradeSize(self)
		local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)


		local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
		effect:setParameter("uuid", sm.uuid.new("f74a0354-05e9-411c-a8ba-75359449f770"))
		effect:setParameter("color", colors[k])
		effect:setScale(size / 4.5)
		effect:setOffsetPosition(offset)
		local rot1 = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))

		--really fucking weird rotation offset thingy bc epic shader doesn't work on all rotations. WTF axolot why?
		local rot2 = self.shape.xAxis.y ~= 0 and sm.vec3.getRotation(sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0))
			or sm.quat.identity()
		effect:setOffsetRotation(rot1 * rot2)

		effect:start()

		self.cl.upgradeEffects[k] = effect
	end

	self.cl.angle = 0
end

---toggles the effect of the sell area
function FortuneWheelFurnace:cl_toggleEffect(active)
	if active and not self.cl.effect:isPlaying() then
		self.cl.effect:start()
		for _, effect in ipairs(self.cl.upgradeEffects) do
			effect:start()
		end
	else
		self.cl.effect:stop()
		for _, effect in ipairs(self.cl.upgradeEffects) do
			effect:stop()
		end
	end
end

function FortuneWheelFurnace:client_onUpdate(dt)
	if self.cl and self.cl.upgradeEffects then
		self.cl.angle = updateAngle(self.cl.angle, dt)
		for k, effect in ipairs(self.cl.upgradeEffects) do
			local angle = (self.cl.angle + (k - 1) * (360 / (#UPGRADES))) % 360
			local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
			effect:setOffsetPosition(offset + moveObjectInCircle(self, angle))
		end
	end
end

-- #endregion

--------------------
-- #region Typings
--------------------

---@class FortuneWheelFurnaceSv : FurnaceSv
---@field angle number current angle of the wheel

---@class FortuneWheelFurnaceCl : FurnaceCl
---@field upgradeEffects table<integer, Effect> effects of the upgrade boxes
---@field angle number current angle of the wheel

-- #endregion
