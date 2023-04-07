dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

---A Chest can be used to store items from your inventory. Stored items cannot be deleted and will be dropped if the Chest is destroyed.
---@class Chest : ShapeClass
---@field sv ChestSv
---@field cl ChestCl
Chest = class(nil)

--------------------
-- #region Server
--------------------

function Chest.server_onCreate(self)
	local container = self.shape.interactable:getContainer(0)
	if not container then
		container = self.shape:getInteractable():addContainer(0, self.data.slots, 65535)
	elseif self.shape.body:isOnLift() then
		--empty container when spawned via lift
		sm.container.beginTransaction()
		for i = 0, container.size, 1 do
			sm.container.setItem(container, i, sm.uuid.getNil(), 0)
		end
		sm.container.endTransaction()
	end

	self.sv = {
		container = container,
		lootList = {},
		cachedPos = self.shape.worldPosition
	}
end

function Chest:server_onFixedUpdate()
	if not sm.exists(self.shape) then return end

	--cache chest data
	self.sv.lootList = {}
	for i = 0, self.sv.container.size, 1 do
		local item = self.sv.container:getItem(i)
		if item.uuid ~= sm.uuid.getNil() then
			self.sv.lootList[#self.sv.lootList + 1] = item
		end
	end

	self.sv.cachedPos = self.shape.worldPosition
end

function Chest.server_onDestroy(self)
	--drop chest contents when destroyed
	---@diagnostic disable-next-line: undefined-global
	SpawnLoot(sm.player.getAllPlayers()[1], self.sv.lootList, self.sv.cachedPos)
end

function Chest.server_canErase(self)
	return self.sv.container:isEmpty()
end

-- #endregion

--------------------
-- #region Client
--------------------

function Chest:client_onCreate()
	self.cl = {}
end

function Chest.client_onInteract(self, character, state)
	if state == true then
		local container = self.shape.interactable:getContainer(0)
		if container then
			self.cl.containerGui = sm.gui.createContainerGui(true)
			self.cl.containerGui:setText("UpperName", "#{CONTAINER_TITLE_GENERIC}")
			self.cl.containerGui:setVisible("TakeAll", true)
			self.cl.containerGui:setContainer("UpperGrid", container);
			self.cl.containerGui:setText("LowerName", "#{INVENTORY_TITLE}")
			self.cl.containerGui:setContainer("LowerGrid", sm.localPlayer.getInventory())
			self.cl.containerGui:open()
		end
	end
end

function Chest.client_onDestroy(self)
	if self.cl.containerGui then
		if sm.exists(self.cl.containerGui) then
			self.cl.containerGui:close()
			self.cl.containerGui:destroy()
		end
	end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ChestSv
---@field container Container
---@field cachedPos Vec3 cached position of the Chest
---@field lootList table <number, Item> list of all items in a Chest

---@class ChestCl
---@field container Container
---@field containerGui GuiInterface gui that is visible when opening the chest


-- #endregion
