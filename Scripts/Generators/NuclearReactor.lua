---A type of `Generator` that produces power when supplied by enriched uranium and water
---@class NuclearReactor : Generator
---@field sv NuclearReactorSv
---@field cl NuclearReactorCl
NuclearReactor = class(nil)

local gears = 10
local pointsPerFuel = 5 * 60
local powerFactor = 1e7
local ambienceTemperature = 21
local startHeat = 100
local endHeat = 320
local maxHeat = 450
local MELTDOWN = 1800

--------------------
-- #region Server
--------------------

---TODO use language tags

function NuclearReactor:server_onCreate()
	Generator.server_onCreate(self)

	---@diagnostic disable-next-line: undefined-field
	self.sv.waterTrigger = NuclearReactor.sv_createAreaTrigger(self, self.data.water)
	self.sv.waterTrigger:bindOnEnter("sv_onEnter")
	self.sv.waterTrigger:bindOnStay("sv_onEnter")
	---@diagnostic disable-next-line: undefined-field
	self.sv.uraniumTrigger = NuclearReactor.sv_createAreaTrigger(self, self.data.uranium)
	self.sv.uraniumTrigger:bindOnEnter("sv_onEnter")
	self.sv.uraniumTrigger:bindOnStay("sv_onEnter")

	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {
			gearIdx = 1,
			uranium = {
				u235 = 0,
				u238 = 0
			},
			heat = ambienceTemperature
		}
	end

	self:sv_setGear(self.sv.saved.gearIdx)
end

function NuclearReactor:sv_createAreaTrigger(data)
	local size = sm.vec3.new(data.box.x, data.box.y, data.box.z)
	local offset = sm.vec3.new(data.offset.x, data.offset.y, data.offset.z)

	return sm.areaTrigger.createAttachedBox(
		self.interactable,
		size / 2,
		offset,
		sm.vec3.getRotation(self.shape.at, self.shape.up),
		sm.areaTrigger.filter.dynamicBody
	)
end

function NuclearReactor:sv_onEnter(trigger, results)
	local filter = (trigger == self.sv.waterTrigger) and "water" or "uranium"

	for _, drop in ipairs(getDrops(results)) do
		if filter == "water" then
			if drop.uuid ~= obj_drop_water then goto continue end

			local heatReduction = self:sv_coolWater()

			sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
				pos = drop:getWorldPosition(),
				value = tostring(heatReduction),
				format = "temperature",
				color = "#3e9ffe",
				effect = "Reactor - GetWater",
			})

			drop:destroyShape(0)
		elseif filter == "uranium" then
			local u235 = drop.uuid == obj_drop_uranium235
			local u238 = drop.uuid == obj_drop_uranium238
			if not (u235 or u238) then goto continue end

			self.sv.saved.uranium.u235 = self.sv.saved.uranium.u235 + (u235 and 1 or 0)
			self.sv.saved.uranium.u238 = self.sv.saved.uranium.u238 + (u238 and 1 or 0)
			self.storage:save(self.sv.saved)

			local color = u238 and "#2e5c06" or "#46e80c"
			sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
				pos = drop:getWorldPosition(),
				value = color .. (u238 and "u238" or "u235"),
				format = nil,
				color = "",
				effect = "Fire -medium01_putout",
			})

			drop:destroyShape(0)
		end
		::continue::
	end
end

---cool the reactor with water
---@return number heatReduction
function NuclearReactor:sv_coolWater()
	local oldHeat = self.sv.saved.heat
	local heatReduction = -self.sv.saved.heat ^ 0.25

	self.sv.saved.heat = math.max(ambienceTemperature, self.sv.saved.heat + heatReduction)
	self.storage:save(self.sv.saved)

	return -(oldHeat - self.sv.saved.heat)
end

function NuclearReactor:server_onFixedUpdate()
	if sm.game.getCurrentTick() % 40 == 0 then
		local power = self:sv_updateHeat()
		PowerManager.sv_changePower(power)

		self.network:setClientData({
			power = tostring(power),
			gearIdx = self.sv.saved.gearIdx,
			heat = self.sv.saved.heat,
		})
		self.storage:save(self.sv.saved)
	end

	sm.physics.applyImpulse(self.shape, self.shape.at * 500, true)
end

function NuclearReactor:sv_updateHeat()
	--air cooling
	self.sv.saved.heat = math.max(ambienceTemperature, self.sv.saved.heat ^ 0.9995)

	--nuclear reaction
	local purity = 0
	local fuel = self.sv.saved.uranium.u235 + self.sv.saved.uranium.u238
	local gearPowerFactor = 0
	if self.sv.saved.uranium.u235 > 0 then
		purity = self.sv.saved.uranium.u235 / (self.sv.saved.uranium.u235 + self.sv.saved.uranium.u238)
		if self.sv.saved.gearIdx > 1 and purity > 0.03 then
			gearPowerFactor = math.min(purity, 0.03 * self.sv.saved.gearIdx) / 0.03
			self.sv.saved.heat = self.sv.saved.heat + 125 * math.min(purity, 0.03 * self.sv.saved.gearIdx)

			self.sv.saved.uranium.u238 = math.max(0, self.sv.saved.uranium.u238 - (1 - purity) / pointsPerFuel)
			self.sv.saved.uranium.u235 = math.max(0, self.sv.saved.uranium.u235 - purity / pointsPerFuel)
		end
	end

	--generatePower
	local efficiency = 0
	local status = ""
	if self.sv.saved.heat >= maxHeat then
		efficiency = 0
		status = "#ff0000TEMPERATURE CRITICAL"
	elseif self.sv.saved.heat >= endHeat then
		efficiency = (maxHeat - self.sv.saved.heat) / (maxHeat - endHeat)
		efficiency = efficiency ^ 0.667
		status = "Efficiency " .. tostring(math.floor(efficiency * 100)) .. "%"
	elseif self.sv.saved.heat >= startHeat then
		efficiency = self.sv.saved.heat / endHeat
		efficiency = efficiency ^ (1 / 3)
		status = "Efficiency " .. tostring(math.floor(efficiency * 100)) .. "%"
	else
		status = "Temparature too low"
	end

	self.network:setClientData({
		status = status,
		purity = purity,
		fuelPoints = fuel
	})
	print(self.sv.saved.uranium)

	local powerGenerated = powerFactor * efficiency * gearPowerFactor

	return powerGenerated
end

function NuclearReactor:sv_setGear(gearIdx, player)
	self.sv.saved.gearIdx = gearIdx

	if gearIdx > 1 and self.sv.saved.uranium.u235 == 0 then
		self.sv.saved.gearIdx = 1
		self.network:sendToClient(player, "cl_msg", "#ff0000You need Uranium 235 to start the reactor")
	else
		self.network:sendToClient(player, "cl_msg",
			"Maximum processed purity: " .. string.format("%.2f", 3 * (gearIdx - 1)) .. "%")
	end

	self.storage:save(self.sv.saved)
	self.network:setClientData({
		gearIdx = self.sv.saved.gearIdx
	})
end

-- #endregion

--------------------
-- #region Client
--------------------

function NuclearReactor:client_onCreate()
	Generator.client_onCreate(self)
	self.cl.gearIdx = 1
	self.cl.heat = 0
	self.cl.status = "Efficiency 0%"
	self.cl.statusGUI = sm.gui.createNameTagGui()
	self.cl.statusGUI:setMaxRenderDistance(100)
	self.cl.purity = 0
	self.cl.fuelPoints = 0

	---@diagnostic disable-next-line: undefined-field
	self.cl.waterEffect = self:cl_createTriggerEffect(self.data.water, sm.color.new(0x3e9ffeff), sm.quat.identity())
	---@diagnostic disable-next-line: param-type-mismatch
	local rot = sm.vec3.getRotation(self.shape.up, -self.shape.up)
	---@diagnostic disable-next-line: undefined-field
	self.cl.uraniumEffect = self:cl_createTriggerEffect(self.data.uranium, sm.color.new(0x2e5c06ff), rot)
end

function NuclearReactor:cl_createTriggerEffect(data, color, rot)
	local size = sm.vec3.new(data.box.x, data.box.y * 7.5, data.box.z)
	local offset = sm.vec3.new(data.offset.x, data.offset.y, data.offset.z)

	local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	effect:setParameter("uuid", sm.uuid.new("f74a0354-05e9-411c-a8ba-75359449f770"))
	effect:setParameter("color", color)
	effect:setScale(size / 4.5)
	effect:setOffsetPosition(offset)
	effect:start()

	local rot1 = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))
	--really fucking weird rotation offset thingy bc epic shader doesn't work on all rotations. WTF axolot why?
	local rot2 = self.shape.xAxis.y ~= 0 and sm.vec3.getRotation(sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0))
		or sm.quat.identity()
	effect:setOffsetRotation(rot)

	return effect
end

function NuclearReactor:client_onInteract(character, state)
	if state == true then
		self.cl.gui = sm.gui.createEngineGui()

		self.cl.gui:setText("Name", sm.shape.getShapeTitle(self.shape.uuid))
		self.cl.gui:setOnCloseCallback("cl_onGuiClosed")
		self.cl.gui:setSliderCallback("Setting", "cl_onSliderChange")
		---@diagnostic disable-next-line: param-type-mismatch
		self.cl.gui:setSliderData("Setting", gears, self.cl.gearIdx - 1)
		self.cl.gui:setIconImage("Icon", self.shape:getShapeUuid())
		self.cl.gui:setButtonCallback("Upgrade", "cl_onUpgradeClicked")

		self:cl_updateGui()

		self.cl.gui:open()
	end
end

function NuclearReactor:client_onClientDataUpdate(data)
	Generator.client_onClientDataUpdate(self, data)

	if data.gearIdx then
		self.cl.gearIdx = data.gearIdx
	end
	if data.heat then
		self.cl.heat = data.heat
	end
	if data.status then
		self.cl.status = data.status
	end
	if data.purity then
		self.cl.purity = data.purity
	end
	if data.fuelPoints then
		self.cl.fuelPoints = data.fuelPoints
	end

	self:cl_updateGui()
end

function NuclearReactor:client_onFixedUpdate()
	if not self.cl.couldInteract then
		self.cl.statusGUI:close()
	end
	self.cl.couldInteract = false
end

function NuclearReactor:cl_updateGui()
	if not self.cl.gui then return end

	self.cl.gui:setSliderPosition("Setting", self.cl.gearIdx - 1)
	self.cl.gui:setText("SubTitle", "#ff0000Heat: " .. format_number({ format = "temperature", value = self.cl.heat }))
	self.cl.gui:setText("Interaction", "Status: " .. self.cl.status)
end

function NuclearReactor:cl_onSliderChange(sliderName, sliderPos)
	self.network:sendToServer("sv_setGear", sliderPos + 1)
	self.cl.gearIdx = sliderPos + 1
end

function NuclearReactor:cl_onGuiClosed()
	self.cl.gui:destroy()
	self.cl.gui = nil
end

function NuclearReactor:cl_msg(msg)
	sm.gui.displayAlertText(msg)
	sm.audio.play("RaftShark")
end

function NuclearReactor:client_canInteract()
	self.cl.statusGUI:setWorldPosition(self.shape.worldPosition + sm.vec3.new(0, 0, 1))
	self.cl.statusGUI:setText("Text",
		"Heat: " .. format_number({ format = "temperature", value = self.cl.heat }) ..
		"\nFuel: " .. string.format("%.2f", self.cl.fuelPoints) ..
		"\nPurity: " .. string.format("%.2f", self.cl.purity * 100) .. "%" ..
		"")
	self.cl.statusGUI:open()
	self.cl.couldInteract = true

	sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true) .. "#{INTERACTION_USE}", "", "")

	return Generator.client_canInteract(self)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class NuclearReactorSv : GeneratorSv
---@field saved NuclearReactorSvSaved
---@field waterTrigger AreaTrigger
---@field uraniumTrigger AreaTrigger

---@class NuclearReactorSvSaved
---@field gearIdx integer
---@field uranium {u235: number, u238: number}
---@field heat number
---@field waste number



---@class NuclearReactorCl : GeneratorCl
---@field gearIdx integer
---@field heat number
---@field status string
---@field gui GuiInterface
---@field waterEffect Effect
---@field uraniumEffect Effect
---@field statusGUI GuiInterface
---@field couldInteract boolean
---@field purity number
---@field fuelPoints number

-- #endregion
