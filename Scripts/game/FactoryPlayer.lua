dofile("$GAME_DATA/Scripts/game/BasePlayer.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_camera.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/util/Timer.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

---A player that plays this amazing custom game mode. Handles stuff like health, and eh effects?
---@class FactoryPlayer : PlayerClass
---@field sv PlayerSv
---@field cl PlayerCl
FactoryPlayer = class(BasePlayer)
--------------------
-- #region Server
--------------------

local MaxHP = 100        --maximum hp a player can have
local StatsTickRate = 40 --how frequent stats update

local RespawnTimeout = 60 * 40
local RespawnFadeDuration = 0.45
local RespawnEndFadeDuration = 0.45
local RespawnFadeTimeout = 5.0
local RespawnDelay = RespawnFadeDuration * 40
local RespawnEndDelay = 1.0 * 40

function FactoryPlayer.server_onCreate(self)
	self.sv = {}

	self.sv.saved = self.storage:load() or {}
	self.sv.saved.stats = self.sv.saved.stats or { hp = MaxHP, maxhp = MaxHP }
	self.sv.saved.isConscious = (self.sv.saved.isConscious == nil) or self.sv.saved.isConscious
	self.sv.saved.isNewPlayer = (self.sv.saved.isNewPlayer == nil) or self.sv.saved.isNewPlayer

	self.storage:save(self.sv.saved)

	self:sv_init()
	self.network:setClientData(self.sv.saved)
end

function FactoryPlayer.sv_init(self)
	BasePlayer.sv_init(self)

	self.sv.statsTimer = Timer()
	self.sv.statsTimer:start(StatsTickRate)

	self.sv.respawn = false
end

function FactoryPlayer.server_onRefresh(self)
	self:sv_init()
	self.network:setClientData(self.sv.saved)
end

function FactoryPlayer.server_onFixedUpdate(self, dt)
	BasePlayer.server_onFixedUpdate(self, dt)

	-- Delays the respawn so clients have time to fade to black
	if self.sv.respawnDelayTimer then
		self.sv.respawnDelayTimer:tick()
		if self.sv.respawnDelayTimer:done() then
			self:sv_e_respawn()
			self.sv.respawnDelayTimer = nil
		end
	end

	-- End of respawn sequence
	if self.sv.respawnEndTimer then
		self.sv.respawnEndTimer:tick()
		if self.sv.respawnEndTimer:done() then
			self.network:sendToClient(self.player, "cl_n_endFadeToBlack", { duration = RespawnEndFadeDuration })
			self.sv.respawnEndTimer = nil;
		end
	end

	-- If respawn failed, restore the character
	if self.sv.respawnTimeoutTimer then
		self.sv.respawnTimeoutTimer:tick()
		if self.sv.respawnTimeoutTimer:done() then
			self:sv_e_onSpawnCharacter()
		end
	end

	if self.player:getCharacter() and self.sv.saved.isConscious then
		self.sv.statsTimer:tick()

		if self.sv.statsTimer:done() then
			self.sv.statsTimer:start(StatsTickRate)

			local maxHpRecovery = 50 * StatsTickRate / (40 * 60)
			local recoverableHp = math.min(self.sv.saved.stats.maxhp - self.sv.saved.stats.hp, maxHpRecovery)
			self.sv.saved.stats.hp = math.min(self.sv.saved.stats.hp + recoverableHp, self.sv.saved.stats.maxhp)

			self.storage:save(self.sv.saved)
			self.network:setClientData(self.sv.saved)
		end
	end
end

function FactoryPlayer.server_onInventoryChanges(self, container, changes)
	self.network:sendToClient(self.player, "cl_n_onInventoryChanges", { container = container, changes = changes })
end

function FactoryPlayer.sv_takeDamage(self, damage, source)
	if damage > 0 then
		---@diagnostic disable-next-line: undefined-global
		damage = damage * GetDifficultySettings().playerTakeDamageMultiplier
		local character = self.player:getCharacter()

		local lockingInteractable = character:getLockingInteractable()
		if lockingInteractable and lockingInteractable:hasSeat() then
			lockingInteractable:setSeatCharacter(character)
		end

		if not g_godMode and self.sv.damageCooldown:done() then
			if self.sv.saved.isConscious then
				self.sv.saved.stats.hp = math.max(self.sv.saved.stats.hp - damage, 0)

				print("'FactoryPlayer' took:", damage, "damage.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp,
					"HP")

				if source then
					self.network:sendToClients("cl_n_onEvent",
						{ event = source, pos = character:getWorldPosition(), damage = damage * 0.01 })
				else
					self.player:sendCharacterEvent("hit")
				end

				if self.sv.saved.stats.hp <= 0 then
					print("'FactoryPlayer' knocked out!")
					self.sv.respawnInteractionAttempted = false
					self.sv.saved.isConscious = false
					character:setTumbling(true)
					character:setDowned(true)
				end

				self.storage:save(self.sv.saved)
				self.network:setClientData(self.sv.saved)
			end
		end
	end
end

function FactoryPlayer.sv_e_respawn(self)
	if self.sv.respawn then
		if not self.sv.respawnTimeoutTimer then
			self.sv.respawnTimeoutTimer = Timer()
			self.sv.respawnTimeoutTimer:start(RespawnTimeout)
		end
		return
	end

	if not self.sv.saved.isConscious then
		self.sv.respawn = true
		sm.event.sendToGame("sv_e_respawn", { player = self.player })
	end
end

function FactoryPlayer.sv_n_tryRespawn(self)
	if not self.sv.saved.isConscious and not self.sv.respawnDelayTimer and not self.sv.respawnInteractionAttempted then
		self.sv.respawnInteractionAttempted = true
		self.sv.respawnEndTimer = nil;
		self.network:sendToClient(self.player, "cl_n_startFadeToBlack",
			{ duration = RespawnFadeDuration, timeout = RespawnFadeTimeout })

		self.sv.respawnDelayTimer = Timer()
		self.sv.respawnDelayTimer:start(RespawnDelay)
	end
end

function FactoryPlayer.sv_e_onSpawnCharacter(self)
	if self.sv.respawn and not self.sv.saved.isNewPlayer then
		local playerBed = g_respawnManager:sv_getPlayerBed(self.player)
		if playerBed and playerBed.shape and sm.exists(playerBed.shape) then
			-- Attempt to seat the respawned character in a bed
			self.network:sendToClient(self.player, "cl_seatCharacter", { shape = playerBed.shape })
		end

		self.sv.respawnEndTimer = Timer()
		self.sv.respawnEndTimer:start(RespawnEndDelay)
	end

	if self.sv.saved.isNewPlayer or self.sv.respawn then
		print("FactoryPlayer", self.player.id, "spawned")
		self.sv.saved.stats.hp = self.sv.saved.isNewPlayer and self.sv.saved.stats.maxhp
			or self.sv.saved.stats.maxhp * 0.3

		self.sv.saved.isConscious = true
		self.sv.saved.isNewPlayer = false

		self.storage:save(self.sv.saved)
		self.network:setClientData(self.sv.saved)

		self.player.character:setTumbling(false)
		self.player.character:setDowned(false)
		self.sv.damageCooldown:start(40 * 5)
	else
		-- FactoryPlayer rejoined the game
		if self.sv.saved.stats.hp <= 0 or not self.sv.saved.isConscious then
			self.player.character:setTumbling(true)
			self.player.character:setDowned(true)
		end
	end

	self.sv.respawnInteractionAttempted = false
	self.sv.respawnDelayTimer = nil
	self.sv.respawnTimeoutTimer = nil
	self.sv.respawn = false

	sm.event.sendToGame("sv_e_onSpawnPlayerCharacter", self.player)
end

---Make all clients fade to black
---@param params table { timeout, duration }
function FactoryPlayer:sv_e_fadeToBlack(params)
	self.network:sendToClients("cl_n_startFadeToBlack",
		{ duration = params.duration or RespawnFadeDuration, timeout = params.timeout or RespawnFadeTimeout })
end

---destroy all drops in the world
function FactoryPlayer:sv_destroyAllDrops()
	for _, body in ipairs(sm.body.getAllBodies()) do
		for _, shape in ipairs(body:getShapes()) do
			local interactable = shape.interactable
			if interactable and interactable:getType() == "scripted" then
				local data = interactable.publicData
				if data and data.value then
					sm.effect.playEffect("PropaneTank - ExplosionSmall", shape.worldPosition)
					shape:destroyShape()
				end
			end
		end
	end
end

function FactoryPlayer:sv_e_takeDamage(params)
	self:sv_takeDamage(params.damage, params.source)
end

-- #endregion

--------------------
-- #region Client
--------------------

function FactoryPlayer.client_onCreate(self)
	BasePlayer.client_onCreate(self)
	self.cl = self.cl or {}

	if self.player == sm.localPlayer.getPlayer() then
		if g_survivalHud then
			g_survivalHud:open()
			g_survivalHud:setVisible("FoodBar", false)
			g_survivalHud:setVisible("WaterBar", false)
		end
	end

	if sm.isHost then
		Effects.cl_init(self)
		self:cl_initNumberEffects()
	end
end

function FactoryPlayer.client_onRefresh(self)
	sm.gui.hideGui(false)
	sm.camera.setCameraState(sm.camera.state.default)
	sm.localPlayer.setLockedControls(false)
end

function FactoryPlayer.client_onClientDataUpdate(self, data)
	BasePlayer.client_onClientDataUpdate(self, data)
	if sm.localPlayer.getPlayer() == self.player then
		if self.cl.stats == nil then self.cl.stats = data.stats end -- First time copy to avoid nil errors

		if g_survivalHud then
			g_survivalHud:setSliderData("Health", data.stats.maxhp * 10 + 1, data.stats.hp * 10)
		end

		self.cl.stats = data.stats
		self.cl.isConscious = data.isConscious
	end
end

function FactoryPlayer.cl_localPlayerUpdate(self, dt)
	BasePlayer.cl_localPlayerUpdate(self, dt)

	if self.player:getCharacter() and not self.cl.isConscious then
		local keyBindingText = sm.gui.getKeyBinding("Use", true)
		sm.gui.setInteractionText("", keyBindingText, "#{INTERACTION_RESPAWN}")
	end
end

function FactoryPlayer.client_onInteract(self, character, state)
	if state then
		if TutorialManager.cl_isTutorialPopUpActive() then
			TutorialManager.cl_closeTutorialPopUp()
		elseif not self.cl.isConscious then
			self.network:sendToServer("sv_n_tryRespawn")
		end
	end
end

function FactoryPlayer.cl_n_onInventoryChanges(self, params)
	if params.container == sm.localPlayer.getInventory() then
		for i, item in ipairs(params.changes) do
			if item.difference > 0 then
				---@diagnostic disable-next-line: undefined-field
				g_survivalHud:addToPickupDisplay(item.uuid, item.difference)
			end
		end
	end
end

function FactoryPlayer.cl_seatCharacter(self, params)
	if sm.exists(params.shape) then
		params.shape.interactable:setSeatCharacter(self.player.character)
	end
end

function FactoryPlayer.client_onCancel(self)
	BasePlayer.client_onCancel(self)
	g_effectManager:cl_cancelAllCinematics()
end

function FactoryPlayer:client_onReload()
	-- clear ores pop-up
	self.cl.confirmClearGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout")
	self.cl.confirmClearGui:setButtonCallback("Yes", "cl_onClearConfirmButtonClick")
	self.cl.confirmClearGui:setButtonCallback("No", "cl_onClearConfirmButtonClick")
	self.cl.confirmClearGui:setText("Title", language_tag("ClearOresTitle"))
	self.cl.confirmClearGui:setText("Message",
		language_tag("ClearOresMessage" .. ((sm.localPlayer.getPlayer():isMale() and "Male") or "Female")))
	self.cl.confirmClearGui:open()
end

function FactoryPlayer:cl_onClearConfirmButtonClick(name)
	if name == "Yes" then
		self.network:sendToServer("sv_destroyAllDrops")
	end
	self.cl.confirmClearGui:close()
	self.cl.confirmClearGui:destroy()
end

function FactoryPlayer:client_onFixedUpdate()
	self:cl_fixedUpdateNumberEffects()
end

function FactoryPlayer:client_onUpdate(deltaTime)
	self:cl_updateNumberEffects(deltaTime)
end

-- #endregion

--------------------
-- #region Effects
--------------------

function FactoryPlayer:cl_initNumberEffects()
	self.cl.numberEffects = {}
end

function FactoryPlayer:cl_fixedUpdateNumberEffects()
	for k, numberEffect in pairs(self.cl.numberEffects) do
		if numberEffect and sm.game.getCurrentTick() > numberEffect.endTick then
			numberEffect.gui:destroy()
			self.cl.numberEffects[k] = nil
		end
	end
end

function FactoryPlayer:cl_updateNumberEffects(deltaTime)
	for k, numberEffect in pairs(self.cl.numberEffects) do
		---@diagnostic disable-next-line: assign-type-mismatch
		numberEffect.pos = numberEffect.pos + sm.vec3.new(0, 0, 0.1) * deltaTime
		numberEffect.gui:setWorldPosition(numberEffect.pos)
	end
end

---Create an effect for all clients. This will be a "floating" text in the world that disappears after a while e.g. selling drops
---@param params NumberEffectParams
function FactoryPlayer:sv_e_numberEffect(params)
	---@diagnostic disable-next-line: assign-type-mismatch
	params.value = format_number({ format = params.format, value = tonumber(params.value), color = params.color })

	self.network:sendToClients("cl_numberEffect", params)
end

---Create an effect for this client. This will be a "floating" text in the world that disappears after a while e.g. selling drops
---@param params NumberEffectParams
function FactoryPlayer:cl_numberEffect(params)
	local gui = sm.gui.createNameTagGui()
	gui:setWorldPosition(params.pos)
	gui:open()
	gui:setMaxRenderDistance(100)
	gui:setText("Text", params.value)

	if params.effect then
		sm.effect.playEffect(params.effect, params.pos - sm.vec3.new(0, 0, 0.25))
	end

	self.cl.numberEffects[#self.cl.numberEffects + 1] = {
		gui = gui,
		endTick = sm.game.getCurrentTick() + 80,
		pos = params.pos
	}
end

function FactoryPlayer:sv_e_playEffect(params)
	self.network:sendToClients("cl_e_playEffect", params)
end

function FactoryPlayer:cl_e_playAudio(effect)
	if sm.localPlayer.getPlayer():getCharacter() then
		sm.audio.play(effect)
	end
end

function FactoryPlayer:cl_e_playEffect(params)
	if params.host ~= nil then
		sm.effect.playHostedEffect(params.effect, params.host.interactable or params.host or sm.localPlayer.getPlayer().character)
	else
		sm.effect.playEffect(params.effect, params.pos or sm.localPlayer.getPlayer().character.worldPosition)
	end
end

function FactoryPlayer:cl_e_createEffect(params)
	Effects.cl_createEffect(self, params)
end

function FactoryPlayer:cl_e_startEffect(key)
	Effects.cl_startEffect(self, key)
end

function FactoryPlayer:cl_e_destroyEffect(key)
	Effects.cl_destroyEffect(self, key)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class PlayerSv
---@field saved PlayerSvSaved
---@field respawnDelayTimer table
---@field respawnEndTimer table
---@field respawnTimeoutTimer table
---@field statsTimer table
---@field damageCooldown table
---@field respawn boolean
---@field respawnInteractionAttempted boolean

---@class PlayerSvSaved
---@field stats PlayerSvSavedStats
---@field isConscious boolean
---@field isNewPlayer boolean

---@class PlayerSvSavedStats
---@field hp number current hp of a player
---@field maxhp number maximum hp a player can have

---@class PlayerCl
---@field isConscious boolean
---@field confirmClearGui GuiInterface
---@field numberEffects table<number, NumberEffect>

---@class NumberEffectParams
---@field value string|number the number value to be displayed
---@field format "money"|"pollution"|"power"|"prestige" format used for displaiyng the value
---@field color string|nil (optional) hex color of the text to be displayed
---@field pos Vec3 worldPosition of the effect
---@field effect string|nil (optional) name of effect to be played while the number effect is created

---@class NumberEffect
---@field gui GuiInterface nameTag gui
---@field endTick number tick at which the effect ends
---@field pos Vec3 world position of the effect

-- #endregion
