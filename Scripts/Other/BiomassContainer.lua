dofile('$CONTENT_DATA/Scripts/util/uuids.lua')
dofile('$CONTENT_DATA/Scripts/Other/DropContainer.lua')

---A biomass container can pickup "biomass" drops. after some time the drop will turn into a gas that can be burned.
---@class BiomassContainer : DropContainer
---@field data BiomassContainerData
---@field sv BiomassContainerSv
---@field cl DropContainerCl
BiomassContainer = class(DropContainer)
BiomassContainer.ContainerSize = 125

---@type table<number, boolean> list of all drops that have been removed by a BiomassContainer during the tick
local removedDrops = {}

---drop uuids that are valid for biomass
local biomassDrops = {
    [tostring(obj_drop_scrap_wood)] = true,
    [tostring(obj_drop_wood)] = true,
    [tostring(obj_drop_popcorn)] = true,
}

--------------------
-- #region Server
--------------------

function BiomassContainer:server_onCreate()
    local container = self.interactable:getContainer(0)
    if not container then
        self.interactable:addContainer(0, self.ContainerSize, 1)
    elseif self.shape.body:isOnLift() then
		--prevent ore duping via lift
		self:sv_emptyContainer()
    end

    self.sv = {
        saved = self.storage:load() or {
            drops = {}
        },
        droppingOffset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z),
        cachedPos = self.shape.worldPosition,
        cachedRot = self.shape.worldRotation
    }
	local shapeSize = sm.item.getShapeSize(self.shape:getShapeUuid()) * 0.125
	local size = sm.vec3.new(shapeSize.x + 0.875, shapeSize.y + 0.875, shapeSize.z + 0.875)
	local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody
	self.sv.areaTrigger = sm.areaTrigger.createAttachedBox(
        self.interactable, size, sm.vec3.zero(), sm.quat.identity(),
		filter, { resourceCollector = self.shape })
	self.sv.areaTrigger:bindOnEnter("sv_trigger_onEnter")
end

function BiomassContainer:server_onFixedUpdate()
    --TODO add biomass drops (12 - 24 secs maybe)

    --cache transform
	self.sv.cachedPos = self.shape.worldPosition
	self.sv.cachedRot = self.shape.worldRotation

    removedDrops = {}
end

function BiomassContainer:sv_trigger_onEnter(_, results)
	for _,result in ipairs(results) do
		if sm.exists(result) and type(result) == "Body" then
            local shape = checkIfDrop(result)
            if shape == nil then goto continue end
            local publicData = shape.interactable.publicData
            if biomassDrops[tostring(shape.uuid)]
                and publicData.burnTime == nil -- don't accept burning drops
                and not removedDrops[shape.id]
            then
                local container = self.interactable:getContainer(0)
                if container then
                    local transactionSlot = self:sv_getLastUsedSlot(container)
                    if transactionSlot then
                        sm.container.beginTransaction()
                        sm.container.collectToSlot(container, transactionSlot, shape:getShapeUuid(), 1, true)

                        if sm.container.endTransaction() then
                            self.network:sendToClients("cl_n_addPickupItem", {
                                shapeUuid = shape:getShapeUuid(),
                                fromPosition = shape.worldPosition,
                                fromRotation = shape.worldRotation,
                                slotIndex = transactionSlot,
                                showRenderable = true
                            })

                            --save drop in storage
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
        ::continue::
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function BiomassContainer:client_canInteract() return false end

-- #endregion

--------------------
-- #region Types
--------------------

---@class BiomassContainerSv
---@field saved BiomassContainerSaveData
---@field droppingOffset Vec3 offset that determines where drops are dropped
---@field cachedPos Vec3
---@field cachedRot Quat

---@class BiomassContainerSaveData : DropContainerSaveData

---@class BiomassContainerData
---@field offset BeltVec the offset for spawning the gas

-- #endregion
