---@class Bed : ShapeClass
Bed = class()

function Bed:server_onDestroy()
	if not self.loaded then return end

	g_respawnManager:sv_destroyBed(self.shape)
	self.loaded = false
end

function Bed:server_onUnload()
	if self.loaded then return end

	g_respawnManager:sv_updateBed(self.shape)
	self.loaded = false
end

function Bed:sv_activateBed(character)
	g_respawnManager:sv_registerBed(self.shape, character)
end

function Bed:server_onCreate()
	self.loaded = true
end

function Bed:server_onFixedUpdate()
	local prevWorld = self.currentWorld
	self.currentWorld = self.shape.body:getWorld()
	if prevWorld == nil and self.currentWorld == prevWorld then return end

	g_respawnManager:sv_updateBed(self.shape)
end

-- Client

function Bed:client_onInteract(character, state)
	if not state then return end

	self.network:sendToServer("sv_activateBed", character)
	self:cl_seat()
	sm.gui.displayAlertText("#{INFO_HOME_STORED}")
end

function Bed:cl_seat()
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter(sm.localPlayer.getPlayer():getCharacter())
	end
end

function Bed:client_onAction(controllerAction, state)
	if not state then return false end

	if controllerAction == sm.interactable.actions.use or controllerAction == sm.interactable.actions.jump then
		self:cl_seat()

		return true
	end

	return false
end
