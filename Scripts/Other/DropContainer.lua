---@class DropContainer : ShapeClass
---@field sv DropContainerSv
---@field cl DropContainerCl
---A drop container can pickup ores and store them. This allows storing and transporting ores. They can also be released again. The DropContainer can be controlled via logic as well, and produces a logic signal if it contains a drop.
DropContainer = class(nil)
DropContainer.ContainerSize = 125
DropContainer.maxParentCount = 1
DropContainer.maxChildCount = 1
DropContainer.connectionOutput = sm.interactable.connectionType.logic
DropContainer.connectionInput = sm.interactable.connectionType.logic
DropContainer.colorNormal = sm.color.new(0x00ccccff)
DropContainer.colorHighlight = sm.color.new(0x00ffffff)

---@type table<number, boolean> list of all drops that have been removed by a DropContainer during the tick
local removedDrops = {}
---drop.shapeset as a desirialized object
local dropShapeset = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/drops.shapeset")



--------------------
-- #region Server
--------------------

function DropContainer.server_onCreate(self)
	local container = self.interactable:getContainer(0)
	if not container then
		container = self.interactable:addContainer(0, self.ContainerSize, 1)
	elseif self.shape.body:isOnLift() then
		--prevent ore duping via lift
		self:sv_emptyContainer()
	end

	self.sv = {}
	local shapeSize = sm.item.getShapeSize(self.shape:getShapeUuid()) * 0.125
	local size = sm.vec3.new(shapeSize.x + 0.875, shapeSize.y + 0.875, shapeSize.z + 0.875)
	local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody +
		sm.areaTrigger.filter.areaTrigger
	self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size, sm.vec3.zero(), sm.quat.identity(),
		filter, { resourceCollector = self.shape })
	self.sv.areaTrigger:bindOnEnter("sv_trigger_onEnter")

	self.sv.saved = self.storage:load()
	if not self.sv.saved then
		self.sv.saved = {}
		self.sv.saved.drops = {}
	end

	self.sv.dropUuids = {}
	for _, part in ipairs(dropShapeset.partList) do
		self.sv.dropUuids[part.uuid] = true
	end

	self.sv.droppingOffset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

	self.prevParentState = false
	self.sv.droppedShapes = {}
end

function DropContainer.server_onFixedUpdate(self)
	--update dropped shapes
	for shapeId, tick in pairs(self.sv.droppedShapes) do
		if tick < sm.game.getCurrentTick() then
			self.sv.droppedShapes[shapeId] = nil
		end
	end

	--check if parent is active
	local parent = self.interactable:getSingleParent()

	if parent then
		if parent.active and not self.prevParentState then
			self:sv_release_drop()
		end
		self.prevParentState = parent.active
	end

	--logic output (true if full)
	local container = self.interactable:getContainer(0)
	local isFull = true
	for i = 0, container.size - 1, 1 do
		local item = container:getItem(i)
		isFull = isFull and item.uuid ~= sm.uuid.getNil()
	end
	self.interactable:setActive(isFull)

	--cache data
	self.sv.cachedPos = self.shape.worldPosition
	self.sv.cachedRot = self.shape.worldRotation


	removedDrops = {}
end

function DropContainer.sv_trigger_onEnter(self, trigger, contents)
	--check objects that entered the areaTrigger
	for _, result in ipairs(contents) do
		if sm.exists(result) and type(result) == "Body" then
			for _, shape in ipairs(result:getShapes()) do
				if self.sv.dropUuids[tostring(shape:getShapeUuid())] and not removedDrops[shape.id] and
					not self.sv.droppedShapes[shape.id] then
					--collect drop
					local container = self.interactable:getContainer(0)

					if container then
						local transactionSlot = self:sv_getLastUsedSlot(container)

						if transactionSlot then
							sm.container.beginTransaction()
							sm.container.collectToSlot(container, transactionSlot, shape:getShapeUuid(), 1, true)

							if sm.container.endTransaction() then
								self.network:sendToClients("cl_n_addPickupItem",
									{
										shapeUuid = shape:getShapeUuid(),
										fromPosition = shape.worldPosition,
										fromRotation = shape.worldRotation,
										slotIndex = transactionSlot,
										showRenderable = true
									})

								--save drop in storage
								local publicData = shape.interactable.publicData
								publicData.uuid = shape:getShapeUuid()
								self.sv.saved.drops[transactionSlot] = packNetworkData(publicData)
								self.storage:save(self.sv.saved)

								--prevent issues from deleted drops
								Drop:Sv_dropStored(shape.id)
								removedDrops[shape.id] = true

								shape:destroyShape()
							end
						end
					end
				end
			end
		end
	end
end

---returns the last slot that is filled in the container
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

---release a drop from the storage, and drop it into the world
function DropContainer:sv_release_drop()
	local container = self.interactable:getContainer(0)

	if container then
		local slotIndex = self:sv_getLastUsedSlot(container) - 1
		local slotItem = container:getItem(slotIndex)

		sm.container.beginTransaction()
		sm.container.spendFromSlot(container, slotIndex, slotItem.uuid, 1, true)

		if sm.container.endTransaction() then
			---create drop
			local publicData = self.sv.saved.drops[slotIndex]
			local offset = self.shape.right * self.sv.droppingOffset.x + self.shape.at * self.sv.droppingOffset.y +
				self.shape.up * self.sv.droppingOffset.z

			---@diagnostic disable-next-line:param-type-mismatch
			local shape = sm.shape.createPart(publicData.uuid, (self.sv.cachedPos or self.shape.worldPosition) + offset,
				self.sv.cachedRot)
			self.sv.droppedShapes[shape.id] = sm.game.getCurrentTick() + 1

			publicData.uuid = nil
			shape.interactable:setPublicData(unpackNetworkData(publicData))

			self.sv.saved.drops[slotIndex] = nil
			self.storage:save(self.sv.saved)
		end
	end
end

function DropContainer:server_canErase()
	self:sv_emptyContainer()
	return true
end

---empty the internal container
function DropContainer:sv_emptyContainer()
	sm.container.beginTransaction()
	local container = self.interactable:getContainer(0)
	for i = 0, container.size, 1 do
		sm.container.setItem(container, i, sm.uuid.getNil(), 0)
	end
	sm.container.endTransaction()
end

function DropContainer:server_onDestroy()
	---release all remaining drops upon destruction
	for slotIndex, publicData in pairs(self.sv.saved.drops) do
		local positionOffset, rotationOffset = self.calculateSlotItemOffset(slotIndex - 1)
		local params = {
			uuid = publicData.uuid,
			pos = self.sv.cachedPos - rotationOffset * positionOffset,
			rot = self.sv.cachedRot,
			publicData = publicData
		}
		params.publicData.uuid = nil

		sm.event.sendToWorld(g_world, "sv_e_createShape", params)
	end
end

-- #endregion

--------------------
-- #region Client
--------------------

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

		local positionOffset, rotationOffset = self.calculateSlotItemOffset(i - 1)
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


		pickupItem.effect:setParameter("uuid", self.cl_getEffectUuid(params.shapeUuid))

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
					local positionOffset, rotationOffset = self.calculateSlotItemOffset(pickupItem.slotIndex)
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
						harvestItem.effect:setParameter("uuid", self.cl_getEffectUuid(slotItem.uuid))
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
		---release drops when interacted with
		local container = self.interactable:getContainer(0)
		if not container:isEmpty() then
			self.network:sendToServer("sv_release_drop")
		end
	end
end

---returns the uuid that should be used for the ShapeRenderable effect of a drop
---@param shapeUuid Uuid
---@return Uuid
function DropContainer.cl_getEffectUuid(shapeUuid)
	for _, drop in ipairs(dropShapeset.partList) do
		if drop.uuid == tostring(shapeUuid) then
			if drop.scripted and drop.scripted.data and drop.scripted.data.effectShape then
				shapeUuid = sm.uuid.new(drop.scripted.data.effectShape)
			end
		end
	end
	return shapeUuid
end

-- #endregion

---returns the offset for each slot with the shape's worldPosition as origin
---@param slotIndex number
---@return Vec3 positionOffset
---@return Quat rotationOffset
function DropContainer.calculateSlotItemOffset(slotIndex)
	local width = 5
	local height = 5
	local depth = 5
	local offsetCornerPosition = sm.vec3.new(-0.5, -0.5, -0.5)
	local rotationOffset = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))
	local positionOffset = offsetCornerPosition +
		sm.vec3.new(0.25 * (slotIndex % width), 0.25 * (math.floor(slotIndex / width / depth) % height),
			0.25 * (math.floor(slotIndex / width) % height))

	---@diagnostic disable-next-line:return-type-mismatch
	return positionOffset, rotationOffset
end

--------------------
-- #region Types
--------------------

---@class DropContainerSv
---@field saved DropContainerSaveData
---@field dropUuids table<string, boolean> a table that contains all uuids of drops
---@field droppingOffset Vec3 offset that determines where drops are dropped
---@field droppedShapes table<number, number> a table of all shapes <id, tick>, so they don't trigger an areaTrigger again
---@field cachedPos Vec3
---@field cachedRot Quat

---@class DropContainerSaveData
---@field drops table<number, table> the saved drops of the container <slot, publicData>

---@class DropContainerCl
---@field harvestItems table<number, table> manages the effect of each item that can be stored in the container?


-- #endregion
