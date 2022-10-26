---@class FactoryPlayer : PlayerClass

dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_camera.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

--FACTORY
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")


FactoryPlayer = class( BasePlayer )


local StatsTickRate = 40
local PerMinute = StatsTickRate / ( 40 * 60 )

local HpRecovery = 50 * PerMinute

local RespawnTimeout = 60 * 40

local RespawnFadeDuration = 0.45
local RespawnEndFadeDuration = 0.45

local RespawnFadeTimeout = 5.0
local RespawnDelay = RespawnFadeDuration * 40
local RespawnEndDelay = 1.0 * 40

local BaguetteSteps = 9

function FactoryPlayer.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	self.sv.saved = self.sv.saved or {}
	self.sv.saved.stats = self.sv.saved.stats or {
		hp = 100, maxhp = 100
	}
	if self.sv.saved.isConscious == nil then self.sv.saved.isConscious = true end
	if self.sv.saved.hasRevivalItem == nil then self.sv.saved.hasRevivalItem = false end
	if self.sv.saved.isNewPlayer == nil then self.sv.saved.isNewPlayer = true end
	if self.sv.saved.tutorialsWatched == nil then self.sv.saved.tutorialsWatched = {} end
	self.storage:save( self.sv.saved )

	self:sv_init()
	self.network:setClientData( self.sv.saved )
end

function FactoryPlayer.server_onRefresh( self )
	self:sv_init()
	self.network:setClientData( self.sv.saved )
end

function FactoryPlayer.sv_init( self )
	BasePlayer.sv_init( self )

	self.sv.statsTimer = Timer()
	self.sv.statsTimer:start( StatsTickRate )

	self.sv.spawnparams = {}
end

function FactoryPlayer.client_onCreate( self )
	BasePlayer.client_onCreate( self )
	self.cl = self.cl or {}
	if self.player == sm.localPlayer.getPlayer() then
		if g_survivalHud then
			g_survivalHud:open()
			g_survivalHud:setVisible("FoodBar", false)
			g_survivalHud:setVisible("WaterBar", false)
		end

		self.cl.tutorialsWatched = {}
		self.cl.effects = {}
	end

	self:cl_init()
end

function FactoryPlayer.client_onRefresh( self )
	self:cl_init()

	sm.gui.hideGui( false )
	sm.camera.setCameraState( sm.camera.state.default )
	sm.localPlayer.setLockedControls( false )
end

function FactoryPlayer.cl_init( self )
	self.cl.revivalChewCount = 0
end

function FactoryPlayer.client_onClientDataUpdate( self, data )
	BasePlayer.client_onClientDataUpdate( self, data )
	if sm.localPlayer.getPlayer() == self.player then

		if self.cl.stats == nil then self.cl.stats = data.stats end -- First time copy to avoid nil errors

		if g_survivalHud then
			g_survivalHud:setSliderData( "Health", data.stats.maxhp * 10 + 1, data.stats.hp * 10 )
		end

		if self.cl.hasRevivalItem ~= data.hasRevivalItem then
			self.cl.revivalChewCount = 0
		end

		self.cl.stats = data.stats
		self.cl.isConscious = data.isConscious
		self.cl.hasRevivalItem = data.hasRevivalItem

		for tutorialKey, _ in pairs( data.tutorialsWatched ) do
			-- Merge saved tutorials and avoid resetting client tutorials
			self.cl.tutorialsWatched[tutorialKey] = true
		end
	end
end

function FactoryPlayer.sv_e_watchedTutorial( self, params, player )
	self.sv.saved.tutorialsWatched[params.tutorialKey] = true
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )
end

function FactoryPlayer.cl_localPlayerUpdate( self, dt )
	BasePlayer.cl_localPlayerUpdate( self, dt )

	local character = self.player:getCharacter()
	if character and not self.cl.isConscious then
		local keyBindingText =  sm.gui.getKeyBinding( "Use", true )
		if self.cl.hasRevivalItem then
			if self.cl.revivalChewCount < BaguetteSteps then
				sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_EAT} ("..self.cl.revivalChewCount.."/10)" )
			else
				sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_REVIVE}" )
			end
		else
			sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_RESPAWN}" )
		end
	end
end

function FactoryPlayer.client_onInteract( self, character, state )
	if state == true then
		if self.cl.tutorialGui and self.cl.tutorialGui:isActive() then
			self.cl.tutorialGui:close()
		end

		if not self.cl.isConscious then
			if self.cl.hasRevivalItem then
				if self.cl.revivalChewCount >= BaguetteSteps then
					self.network:sendToServer( "sv_n_revive" )
				end
				self.cl.revivalChewCount = self.cl.revivalChewCount + 1
				self.network:sendToServer( "sv_onEvent", { type = "character", data = "chew" } )
			else
				self.network:sendToServer( "sv_n_tryRespawn" )
			end
		end
	end
end

function FactoryPlayer.server_onFixedUpdate( self, dt )
	BasePlayer.server_onFixedUpdate( self, dt )

	if g_survivalDev and not self.sv.saved.isConscious and not self.sv.saved.hasRevivalItem then
		if sm.container.canSpend( self.player:getInventory(), obj_consumable_longsandwich, 1 ) then
			if sm.container.beginTransaction() then
				sm.container.spend( self.player:getInventory(), obj_consumable_longsandwich, 1, true )
				if sm.container.endTransaction() then
					self.sv.saved.hasRevivalItem = true
					self.player:sendCharacterEvent( "baguette" )
					self.network:setClientData( self.sv.saved )
				end
			end
		end
	end

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
			self.network:sendToClient( self.player, "cl_n_endFadeToBlack", { duration = RespawnEndFadeDuration } )
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

	local character = self.player:getCharacter()

	if character and self.sv.saved.isConscious and not g_godMode then
		self.sv.statsTimer:tick()
		if self.sv.statsTimer:done() then
			self.sv.statsTimer:start( StatsTickRate )

			-- Normal recovery
			local recoverableHp = math.min( self.sv.saved.stats.maxhp - self.sv.saved.stats.hp, HpRecovery)
			self.sv.saved.stats.hp = math.min( self.sv.saved.stats.hp + recoverableHp, self.sv.saved.stats.maxhp )

			self.storage:save( self.sv.saved )
			self.network:setClientData( self.sv.saved )
		end
	end
end

function FactoryPlayer.server_onInventoryChanges( self, container, changes )
	self.network:sendToClient( self.player, "cl_n_onInventoryChanges", { container = container, changes = changes } )		
end

function FactoryPlayer.sv_e_staminaSpend( self, stamina )
	return
end

function FactoryPlayer.sv_takeDamage( self, damage, source )
	if damage > 0 then
		damage = damage * GetDifficultySettings().playerTakeDamageMultiplier
		local character = self.player:getCharacter()
		local lockingInteractable = character:getLockingInteractable()
		if lockingInteractable and lockingInteractable:hasSeat() then
			lockingInteractable:setSeatCharacter( character )
		end

		if not g_godMode and self.sv.damageCooldown:done() then
			if self.sv.saved.isConscious then
				self.sv.saved.stats.hp = math.max( self.sv.saved.stats.hp - damage, 0 )

				print( "'FactoryPlayer' took:", damage, "damage.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp, "HP" )

				if source then
					self.network:sendToClients( "cl_n_onEvent", { event = source, pos = character:getWorldPosition(), damage = damage * 0.01 } )
				else
					self.player:sendCharacterEvent( "hit" )
				end

				if self.sv.saved.stats.hp <= 0 then
					print( "'FactoryPlayer' knocked out!" )
					self.sv.respawnInteractionAttempted = false
					self.sv.saved.isConscious = false
					character:setTumbling( true )
					character:setDowned( true )
				end

				self.storage:save( self.sv.saved )
				self.network:setClientData( self.sv.saved )
			end
		else
			print( "'FactoryPlayer' resisted", damage, "damage" )
		end
	end
end

function FactoryPlayer.sv_n_revive( self )
	local character = self.player:getCharacter()
	if not self.sv.saved.isConscious and self.sv.saved.hasRevivalItem and not self.sv.spawnparams.respawn then
		print( "FactoryPlayer", self.player.id, "revived" )
		self.sv.saved.stats.hp = self.sv.saved.stats.maxhp
		self.sv.saved.isConscious = true
		self.sv.saved.hasRevivalItem = false
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self.network:sendToClient( self.player, "cl_n_onEffect", { name = "Eat - EatFinish", host = self.player.character } )
		if character then
			character:setTumbling( false )
			character:setDowned( false )
		end
		self.sv.damageCooldown:start( 40 )
		self.player:sendCharacterEvent( "revive" )
	end
end

function FactoryPlayer.sv_e_respawn( self )
	if self.sv.spawnparams.respawn then
		if not self.sv.respawnTimeoutTimer then
			self.sv.respawnTimeoutTimer = Timer()
			self.sv.respawnTimeoutTimer:start( RespawnTimeout )
		end
		return
	end
	if not self.sv.saved.isConscious then
		self.sv.spawnparams.respawn = true

		sm.event.sendToGame( "sv_e_respawn", { player = self.player } )
	else
		print( "FactoryPlayer must be unconscious to respawn" )
	end
end

function FactoryPlayer.sv_n_tryRespawn( self )
	if not self.sv.saved.isConscious and not self.sv.respawnDelayTimer and not self.sv.respawnInteractionAttempted then
		self.sv.respawnInteractionAttempted = true
		self.sv.respawnEndTimer = nil;
		self.network:sendToClient( self.player, "cl_n_startFadeToBlack", { duration = RespawnFadeDuration, timeout = RespawnFadeTimeout } )

		self.sv.respawnDelayTimer = Timer()
		self.sv.respawnDelayTimer:start( RespawnDelay )
	end
end

function FactoryPlayer.sv_e_onSpawnCharacter( self )
	if self.sv.saved.isNewPlayer then

	elseif self.sv.spawnparams.respawn then
		local playerBed = g_respawnManager:sv_getPlayerBed( self.player )
		if playerBed and playerBed.shape and sm.exists( playerBed.shape ) and playerBed.shape.body:getWorld() == self.player.character:getWorld() then
			-- Attempt to seat the respawned character in a bed
			self.network:sendToClient( self.player, "cl_seatCharacter", { shape = playerBed.shape  } )
		end

		self.sv.respawnEndTimer = Timer()
		self.sv.respawnEndTimer:start( RespawnEndDelay )
	end

	if self.sv.saved.isNewPlayer or self.sv.spawnparams.respawn then
		print( "FactoryPlayer", self.player.id, "spawned" )
		if self.sv.saved.isNewPlayer then
			self.sv.saved.stats.hp = self.sv.saved.stats.maxhp
		else
			self.sv.saved.stats.hp = 30
		end
		self.sv.saved.isConscious = true
		self.sv.saved.hasRevivalItem = false
		self.sv.saved.isNewPlayer = false
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )

		self.player.character:setTumbling( false )
		self.player.character:setDowned( false )
		self.sv.damageCooldown:start( 40*5 )
	else
		-- FactoryPlayer rejoined the game
		if self.sv.saved.stats.hp <= 0 or not self.sv.saved.isConscious then
			self.player.character:setTumbling( true )
			self.player.character:setDowned( true )
		end
	end

	self.sv.respawnInteractionAttempted = false
	self.sv.respawnDelayTimer = nil
	self.sv.respawnTimeoutTimer = nil
	self.sv.spawnparams = {}

	sm.event.sendToGame( "sv_e_onSpawnPlayerCharacter", self.player )
end

function FactoryPlayer.cl_n_onInventoryChanges( self, params )
	if params.container == sm.localPlayer.getInventory() then
		for i, item in ipairs( params.changes ) do
			if item.difference > 0 then
				g_survivalHud:addToPickupDisplay( item.uuid, item.difference )
			end
		end
	end
end

function FactoryPlayer.cl_seatCharacter( self, params )
	if sm.exists( params.shape ) then
		params.shape.interactable:setSeatCharacter( self.player.character )
	end
end

function FactoryPlayer.sv_e_eat( self, edibleParams )
	if edibleParams.hpGain then
		self:sv_restoreHealth( edibleParams.hpGain )
	end
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )
end

function FactoryPlayer.sv_e_feed( self, params )
	if not self.sv.saved.isConscious and not self.sv.saved.hasRevivalItem then
		if sm.container.beginTransaction() then
			sm.container.spend( params.playerInventory, params.foodUuid, 1, true )
			if sm.container.endTransaction() then
				self.sv.saved.hasRevivalItem = true
				self.player:sendCharacterEvent( "baguette" )
				self.network:setClientData( self.sv.saved )
			end
		end
	end
end

function FactoryPlayer.sv_restoreHealth( self, health )
	if self.sv.saved.isConscious then
		self.sv.saved.stats.hp = self.sv.saved.stats.hp + health
		self.sv.saved.stats.hp = math.min( self.sv.saved.stats.hp, self.sv.saved.stats.maxhp )
		print( "'FactoryPlayer' restored:", health, "health.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp, "HP" )
	end
end

function FactoryPlayer.client_onCancel( self )
	BasePlayer.client_onCancel( self )
	g_effectManager:cl_cancelAllCinematics()
end


--FACTORY
function FactoryPlayer:sv_e_fadeToBlack(params)
	self.network:sendToClients("cl_n_startFadeToBlack", { duration = params.duration or RespawnFadeDuration, timeout = params.timeout or RespawnFadeTimeout } )
end

function FactoryPlayer:cl_e_drop_dropped()
	if not self.cl.tutorialsWatched["oreDestroy"] then
		if not self.cl.tutorialGui then
			self.cl.tutorialGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true, { isHud = true, isInteractive = false, needsCursor = false } )
			self.cl.tutorialGui:setText( "TextTitle", language_tag("ClearOresTutorialTitle") )
			self.cl.tutorialGui:setText( "TextMessage", language_tag("ClearOresTutorialMessage"):format(sm.gui.getKeyBinding( "Reload" )))
			local dismissText = string.format( language_tag("DismissTutorial"):format(sm.gui.getKeyBinding( "Use" )) )
			self.cl.tutorialGui:setText( "TextDismiss", dismissText )
			self.cl.tutorialGui:setImage( "ImageTutorial", "$CONTENT_DATA/Gui/Images/tutorial_destroy_ore.png")
			self.cl.tutorialGui:setOnCloseCallback( "cl_onCloseTutorialOreDestroyGui" )
			self.cl.tutorialGui:open()
		end
	end
end

function FactoryPlayer.cl_onCloseTutorialOreDestroyGui( self )
	self.cl.tutorialsWatched["oreDestroy"] = true
	self.network:sendToServer( "sv_e_watchedTutorial", { tutorialKey = "oreDestroy" } )
	self.cl.tutorialGui = nil
end

function FactoryPlayer:sv_destroyOre()
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

function FactoryPlayer:cl_e_audio(effect)
	if sm.localPlayer.getPlayer():getCharacter() and (not self.lastPlay or sm.game.getCurrentTick() > self.lastPlay + 40) then
		sm.audio.play(effect)
		self.lastPlay = sm.game.getCurrentTick()
	end
end

function FactoryPlayer:client_onReload()
	self.cl.confirmClearGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )
	self.cl.confirmClearGui:setButtonCallback( "Yes", "cl_onClearConfirmButtonClick" )
	self.cl.confirmClearGui:setButtonCallback( "No", "cl_onClearConfirmButtonClick" )
	self.cl.confirmClearGui:setText( "Title", language_tag("ClearOresTitle") )
	self.cl.confirmClearGui:setText( "Message", language_tag("ClearOresMessage") )
	self.cl.confirmClearGui:open()
end

function FactoryPlayer:cl_onClearConfirmButtonClick(name)
	if name == "Yes" then
		self.network:sendToServer("sv_destroyOre")
	end
	self.cl.confirmClearGui:close()
	self.cl.confirmClearGui:destroy()
end




--Effects

function FactoryPlayer:cl_e_playAudio(name)
	sm.audio.play(name)
end

function FactoryPlayer:sv_e_playEffect(params)
	self.network:sendToClients("cl_e_playEffect", params)
end

function FactoryPlayer:cl_e_playEffect(params)
	sm.effect.playEffect(params.effect, params.pos or sm.localPlayer.getPlayer().character.worldPosition)
end

function FactoryPlayer:cl_e_createEffect(params)
	self.cl.effects[params.id] = sm.effect.createEffect(params.effect, params.host)
end

function FactoryPlayer:cl_e_startEffect(id)
	if self.cl.effects[id] and not self.cl.effects[id]:isPlaying() then
		self.cl.effects[id]:start()
	end
end

function FactoryPlayer:cl_e_destroyEffect(id)
	if self.cl.effects[id] then
		self.cl.effects[id]:destroy()
		self.cl.effects[id] = nil
	end
end