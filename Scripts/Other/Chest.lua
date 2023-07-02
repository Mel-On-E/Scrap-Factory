dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

---A Chest can be used to store items from your inventory. Stored items cannot be deleted and will be dropped if the Chest is destroyed.
---@class Chest : ShapeClass
---@field sv ChestSv
---@field cl ChestCl
Chest = class(nil)
Chest.poseWeightCount = 1

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
		cachedPos = self.shape.worldPosition,
		playersHavingChestGuiOpen = 0
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

function Chest.sv_openChestAnim(self)
	self.sv.playersHavingChestGuiOpen = self.sv.playersHavingChestGuiOpen + 1
	if self.sv.playersHavingChestGuiOpen == 1 then
		self.network:sendToClients("cl_openChestAnim")
	end
end

function Chest.sv_closeChestAnim(self)
	self.sv.playersHavingChestGuiOpen = self.sv.playersHavingChestGuiOpen - 1
	if self.sv.playersHavingChestGuiOpen == 0 then
		self.network:sendToClients("cl_closeChestAnim")
	end
end

-- #endregion

--------------------
-- #region Client
--------------------

local chestOpeningSpeed = 8.0

function Chest:client_onCreate()
	self.cl = {
		chestAnimDirection = -1
	}
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
			self.cl.containerGui:setOnCloseCallback("cl_guiClosed")
			self.cl.containerGui:open()

			sm.effect.playEffect("Chest Open", self.shape.worldPosition)
			self.network:sendToServer("sv_openChestAnim")
		end
	end
end

function Chest.cl_guiClosed(self)
	self.network:sendToServer("sv_closeChestAnim")
	sm.effect.playEffect("Chest Close", self.shape.worldPosition)
end

function Chest.client_onDestroy(self)
	if self.cl.containerGui then
		if sm.exists(self.cl.containerGui) then
			self.cl.containerGui:close()
			self.cl.containerGui:destroy()
		end
	end
end

function Chest.cl_openChestAnim(self)
	self.cl.chestAnimDirection = 1
end

function Chest.cl_closeChestAnim(self)
	self.cl.chestAnimDirection = -1
end

function Chest.client_onUpdate(self, dt)
	local poseWeight = self.interactable:getPoseWeight(0)
	poseWeight = poseWeight + (chestOpeningSpeed * self.cl.chestAnimDirection) * dt
	poseWeight = sm.util.clamp(poseWeight, 0, 1)
	self.interactable:setPoseWeight(0, poseWeight)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ChestSv
---@field container Container
---@field cachedPos Vec3 cached position of the Chest
---@field lootList table <number, Item> list of all items in a Chest
---@field playersHavingChestGuiOpen integer how many players have the chest opened rn

---@class ChestCl
---@field containerGui GuiInterface gui that is visible when opening the chest
---@field chestAnimDirection -1|1 whehter the chest keeps opening or closing


-- #endregion
