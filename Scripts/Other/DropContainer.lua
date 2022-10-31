---@class DropContainer : ShapeClass
DropContainer = class(nil)
DropContainer.ContainerSize = 125
DropContainer.maxParentCount = 1
DropContainer.maxChildCount = 1
DropContainer.connectionOutput = sm.interactable.connectionType.logic
DropContainer.connectionInput = sm.interactable.connectionType.logic
DropContainer.colorNormal = sm.color.new(0x00ccccff)
DropContainer.colorHighlight = sm.color.new(0x00ffffff)

function DropContainer.server_onCreate(self)
	if not self.interactable:getContainer(0) then
		self.interactable:addContainer(0, self.ContainerSize, 1)
	end

	self.sv = {}
	local shapeSize = sm.item.getShapeSize(self.shape:getShapeUuid()) * 0.125
	local size = sm.vec3.new(shapeSize.x + 0.875, shapeSize.y + 0.875, shapeSize.z + 0.875)
	local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.areaTrigger
	self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, sm.vec3.zero(), sm.quat.identity(),
		filter, { resourceCollector = self.shape })
	self.sv.areaTrigger:bindOnEnter("trigger_onEnter")

	self.sv.saved = self.storage:load()
	if not self.sv.saved then
		self.sv.saved = {}
		self.sv.saved.drops = {}
	end

	self.sv.drops = {}
	local drop_json = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/drops.shapeset")
	for _, part in ipairs(drop_json.partList) do
		self.sv.drops[part.uuid] = true
	end

	self.offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
	self.prevParentState = false
end

local RemovedHarvests = {}
local droppedShapes = {}

function DropContainer.server_onFixedUpdate(self)
	RemovedHarvests = {}
	for key, jank in pairs(droppedShapes) do
		if jank < sm.game.getCurrentTick() then
			droppedShapes[key] = nil
		end
	end

	local container = self.interactable:getContainer(0)
	self.interactable:setActive(not container:isEmpty())

	local parent = self.interactable:getSingleParent()

	if parent then
		if parent.active and not self.prevParentState then
			self:sv_release_drop()
		end
		self.prevParentState = parent.active
	end
end

function DropContainer.trigger_onEnter(self, trigger, contents)
	for _, result in ipairs(contents) do
		if sm.exists(result) and type(result) == "Body" then
			for _, shape in ipairs(result:getShapes()) do
				if self.sv.drops[tostring(shape:getShapeUuid())] and not RemovedHarvests[shape:getId()] and
					not droppedShapes[shape:getId()] then
					local container = self.interactable:getContainer(0)
					if container then
						local transactionSlot = nil
						for i = 1, self.ContainerSize do
							local slotItem = container:getItem(i - 1)
							if slotItem.quantity == 0 then
								transactionSlot = i - 1
								break
							end
						end

						if transactionSlot then
							sm.container.beginTransaction()
							sm.container.collectToSlot(container, transactionSlot, shape:getShapeUuid(), 1, true)
							if sm.container.endTransaction() then
								self.network:sendToClients("cl_n_addPickupItem",
									{ shapeUuid = shape:getShapeUuid(), fromPosition = shape.worldPosition, fromRotation = shape.worldRotation,
										slotIndex = transactionSlot, showRenderable = true })
								RemovedHarvests[shape:getId()] = true

								local publicData = shape.interactable.publicData

								self.sv.saved.drops[transactionSlot] = packNetworkData(publicData)
								self.storage:save(self.sv.saved)

								shape:destroyShape()
							end
						end
					end
				end
			end
		end
	end
end

function DropContainer:sv_getLastUsedSlot(container)
	local transactionSlot = nil
	for i = 1, self.ContainerSize do
		local slotItem = container:getItem(i - 1)
		if slotItem.quantity == 0 then
			transactionSlot = i - 1
			break
		end
	end
	return transactionSlot or self.ContainerSize
end

function DropContainer.sv_release_drop(self)
	local container = self.interactable:getContainer(0)
	if container then
		local slotIndex = self:sv_getLastUsedSlot(container) - 1
		local slotItem = container:getItem(slotIndex)
		sm.container.beginTransaction()
		sm.container.spendFromSlot(container, slotIndex, slotItem.uuid, 1, true)
		if sm.container.endTransaction() then
			local offset = self.shape.right * self.offset.x + self.shape.at * self.offset.y + self.shape.up * self.offset.z

			local shape = sm.shape.createPart(slotItem.uuid, self.shape.worldPosition + offset, self.shape:getWorldRotation())
			droppedShapes[shape:getId()] = sm.game.getCurrentTick() + 1

			local publicData = self.sv.saved.drops[slotIndex]
			shape.interactable:setPublicData(unpackNetworkData(publicData))

			self.sv.saved.drops[slotIndex] = nil
			self.storage:save(self.sv.saved)
		end
	end
end

function DropContainer:server_canErase()
	local container = self.interactable:getContainer(0)
	return container:isEmpty()
end

function DropContainer.client_onCreate(self)
	self:cl_init()
end

function DropContainer.client_onRefresh(self)
	if self.cl then
		if self.cl.harvestItems then
			for _, harvestItem in ipairs(self.cl.harvestItems) do
				if harvestItem.effect then
					harvestItem.effect:stop()
				end
			end
		end
	end
	self:cl_init()
end

function DropContainer.client_onDestroy(self)
	for _, harvestItem in ipairs(self.cl.harvestItems) do
		if harvestItem.effect then
			harvestItem.effect:stop()
		end
	end
end

function DropContainer.cl_init(self)
	self.cl = {}
	self.cl.pickupItems = {}

	self.cl.harvestItems = {}
	for i = 1, self.ContainerSize do
		local harvestItem = {}
		harvestItem.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)

		local positionOffset, rotationOffset = self:calculateSlotItemOffset(i - 1)
		harvestItem.effect:setOffsetPosition(positionOffset)
		harvestItem.effect:setOffsetRotation(rotationOffset)
		harvestItem.effect:setScale(sm.vec3.new(0.25, 0.25, 0.25))
		harvestItem.enteringContainer = false

		self.cl.harvestItems[#self.cl.harvestItems + 1] = harvestItem
	end
end

function DropContainer.cl_n_addPickupItem(self, params)
	if self.cl == nil then
		self.cl = {}
	end
	if self.cl.pickupItems == nil then
		self.cl.pickupItems = {}
	end

	if params.showRenderable then
		local pickupItem = {}
		pickupItem.effect = sm.effect.createEffect("ShapeRenderable")
		pickupItem.effect:setParameter("uuid", params.shapeUuid)
		pickupItem.effect:setPosition(params.fromPosition)
		pickupItem.effect:setRotation(params.fromRotation)
		pickupItem.effect:setScale(sm.vec3.new(0.25, 0.25, 0.25))
		pickupItem.effect:start()
		pickupItem.elapsedTime = 0.0
		pickupItem.fromPosition = params.fromPosition
		pickupItem.fromRotation = params.fromRotation
		pickupItem.slotIndex = params.slotIndex

		self.cl.pickupItems[#self.cl.pickupItems + 1] = pickupItem
	end

	-- Added resource effect
	sm.effect.playEffect("Resourcecollector - TakeOut", self.shape.worldPosition)
end

function DropContainer.client_onUpdate(self, dt)

	local container = self.interactable:getContainer(0)
	if container then

		-- Update pickup item effects
		local pickupTime = 0.3
		local remainingPickupItems = {}
		for _, pickupItem in ipairs(self.cl.pickupItems) do
			pickupItem.elapsedTime = pickupItem.elapsedTime + dt
			if pickupItem.elapsedTime >= pickupTime then
				pickupItem.effect:stop()
				self.cl.harvestItems[pickupItem.slotIndex + 1].enteringContainer = false
			else
				self.cl.harvestItems[pickupItem.slotIndex + 1].enteringContainer = true
				local windup = 0.4
				local progress = math.min(pickupItem.elapsedTime / pickupTime, 1.0)
				if progress > windup then
					local positionOffset, rotationOffset = self:calculateSlotItemOffset(pickupItem.slotIndex)
					local toPosition = self.shape.worldPosition + self.shape.worldRotation * positionOffset
					local toRotation = self.shape.worldRotation * rotationOffset
					local windupProgress = ((progress - windup) / (1 - windup))
					pickupItem.effect:setPosition(sm.vec3.lerp(pickupItem.fromPosition, toPosition, windupProgress))
					pickupItem.effect:setRotation(sm.quat.slerp(pickupItem.fromRotation, toRotation, windupProgress))
				end
				remainingPickupItems[#remainingPickupItems + 1] = pickupItem
			end
		end
		self.cl.pickupItems = remainingPickupItems

		-- Update attached renderable effects
		for i = 1, self.ContainerSize do
			local slotItem = container:getItem(i - 1)
			local harvestItem = self.cl.harvestItems[i]
			if harvestItem.effect then
				if slotItem.uuid == sm.uuid.getNil() then
					if harvestItem.effect:isPlaying() then
						harvestItem.effect:stop()
					end
				else
					if not harvestItem.effect:isPlaying() and not harvestItem.enteringContainer then
						harvestItem.effect:setParameter("uuid", slotItem.uuid)
						harvestItem.effect:start()
					end
				end
			end
		end
	end
end

function DropContainer.client_canInteract(self)
	local container = self.interactable:getContainer(0)
	if container and not container:isEmpty() then
		sm.gui.setCenterIcon("Use")
		local keyBindingText = sm.gui.getKeyBinding("Use", true)
		sm.gui.setInteractionText("", keyBindingText, "Release Ore")
		return true
	end
	return false
end

function DropContainer.client_onInteract(self, user, state)
	if state then
		local container = self.interactable:getContainer(0)
		if not container:isEmpty() then
			self.network:sendToServer("sv_release_drop")
		end
	end
end

function DropContainer.calculateSlotItemOffset(self, slotIndex)
	local width = 5
	local height = 5
	local depth = 5
	local offsetCornerPosition = sm.vec3.new(-0.5, -0.5, -0.5)
	local rotationOffset = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))
	local positionOffset = offsetCornerPosition +
		sm.vec3.new(0.25 * (slotIndex % width), 0.25 * (math.floor(slotIndex / width / depth) % height),
			0.25 * (math.floor(slotIndex / width) % height))

	return positionOffset, rotationOffset
end
