--vanila survival
dofile("$SURVIVAL_DATA/Scripts/game/managers/BeaconManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua")
dofile("$SURVIVAL_DATA/Scripts/game/util/recipes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/util/Timer.lua")
dofile("$GAME_DATA/Scripts/game/managers/EventManager.lua")

--custom
dofile("$CONTENT_DATA/Scripts/Managers/RespawnManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/UnitManager.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")
dofile("$CONTENT_DATA/Scripts/util/effects.lua")
dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/util/uuids.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/MoneyManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PowerManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/ResearchManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PollutionManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PrestigeManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LootCrateManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PerkManager.lua")

---Manages the game, world, and more stuff
---@class FactoryGame : GameClass
---@field sv FactoryGameSv
---@field cl FactoryGameCl
FactoryGame = class(nil)
FactoryGame.enableLimitedInventory = true
FactoryGame.enableRestrictions = true
FactoryGame.enableFuelConsumption = false
FactoryGame.enableAmmoConsumption = false
FactoryGame.enableUpgrade = true
FactoryGame.defaultInventorySize = 1024

--------------------
-- #region Server
--------------------

---How often client and host time is synced
local SyncInterval = 400 -- 400 ticks | 10 seconds

function FactoryGame.server_onCreate(self)
	print("FactoryGame.server_onCreate")

	self.sv = {}

	self:sv_loadSavedData()

	g_world = self.sv.saved.world
	g_enableCollisionTumble = true

	self:sv_initManagers()
	self:sv_initTimeSync()
end

function FactoryGame.server_onFixedUpdate(self, timeStep)
	self:sv_updateTimeStuff(timeStep)

	g_unitManager:sv_onFixedUpdate()
	if g_eventManager then
		g_eventManager:sv_onFixedUpdate()
	end

	if sm.game.getCurrentTick() % 40 == 0 then
		self:sv_updateClientData()
	end
end

function FactoryGame.server_onPlayerJoined(self, player, newPlayer)
	print(player.name, "joined the game")

	if newPlayer then --Player is first time joiners
		local inventory = player:getInventory()

		local tool_connect = sm.uuid.new("8c7efc37-cd7c-4262-976e-39585f8527bf")

		local startingItems = {
			tool_hammer, tool_lift, tool_connect, tool_sell, obj_dropper_scrap_wood, obj_furnace_basic,
			obj_generator_windmill
		}

		sm.container.beginTransaction()

		for slot, item in ipairs(startingItems) do
			sm.container.setItem(inventory, slot - 1, item, 1)
		end

		for i = #startingItems, inventory.size, 1 do
			sm.container.setItem(inventory, i, sm.uuid.getNil(), 0)
		end

		local i = #startingItems

		--perk items
		for _, item in ipairs(g_perkManager.sv.items) do
			sm.container.setItem(inventory, i, item, 1)
			i = i + 1
		end

		--special items for host only
		if sm.player.getAllPlayers()[1] == player then --if host
			for uuid, quantity in pairs(PrestigeManager.sv_getSpecialItems()) do
				sm.container.setItem(inventory, i, sm.uuid.new(uuid), quantity)
				i = i + 1
			end
		end

		sm.container.endTransaction()

		if not sm.exists(self.sv.saved.world) then
			sm.world.loadWorld(self.sv.saved.world)
		end
		self.sv.saved.world:loadCell(math.floor(SPAWN_POINT.x / 64), math.floor(SPAWN_POINT.y / 64), player,
			"sv_createNewPlayer")
	end
	g_unitManager:sv_onPlayerJoined(player)
end

--------------------
-- #region Spawning
--------------------

function FactoryGame.sv_createNewPlayer(self, world, x, y, player)
	local params = { player = player, x = x, y = y }
	sm.event.sendToWorld(self.sv.saved.world, "sv_spawnNewCharacter", params)
end

---sets the `SPAWN_POINT` for all players
---@param pos Vec3
function FactoryGame.sv_e_setSpawnPoint(self, pos)
	self.sv.saved.spawn = pos
	SPAWN_POINT = pos
	self.storage:save(self.sv.saved)
end

function FactoryGame.sv_e_respawn(self, params)
	if params.player.character and sm.exists(params.player.character) then
		g_respawnManager:sv_requestRespawnCharacter(params.player)
	else
		if not sm.exists(self.sv.saved.world) then
			sm.world.loadWorld(self.sv.saved.world)
		end
		self.sv.saved.world:loadCell(math.floor(SPAWN_POINT.x / 64), math.floor(SPAWN_POINT.y / 64), params
			.player,
			"sv_createNewPlayer")
	end
end

function FactoryGame.sv_loadedRespawnCell(self, world, x, y, player)
	g_respawnManager:sv_respawnCharacter(player, world)
end

function FactoryGame.sv_e_onSpawnPlayerCharacter(self, player)
	if player.character and sm.exists(player.character) then
		g_respawnManager:sv_onSpawnCharacter(player)
		g_beaconManager:sv_onSpawnCharacter(player)
	else
		sm.log.warning("FactoryGame.sv_e_onSpawnPlayerCharacter for a character that doesn't exist")
	end
end

-- #endregion

--------------------
-- #region Commands
--------------------

function FactoryGame.sv_onChatCommand(self, params, player)
	if params[1] == "/sethp" then
		sm.event.sendToPlayer(player, "sv_e_debug", { hp = params[2] })
	elseif params[1] == "/respawn" then
		sm.event.sendToPlayer(player, "sv_e_respawn")
	elseif params[1] == "/printglobals" then
		print("Globals:")
		for k, _ in pairs(_G) do
			print(k)
		end

		--FACTORY
	elseif params[1] == "/addmoney" then
		MoneyManager.sv_addMoney(tonumber(params[2]))
	elseif params[1] == "/setmoney" then
		MoneyManager.sv_setMoney(tonumber(params[2]))
	elseif params[1] == "/addpollution" then
		PollutionManager.sv_addPollution(tonumber(params[2]))
	elseif params[1] == "/setpollution" then
		PollutionManager.sv_setPollution(tonumber(params[2]))
	elseif params[1] == "/addprestige" then
		PrestigeManager.sv_addPrestige(tonumber(params[2]))
	elseif params[1] == "/setprestige" then
		PrestigeManager.sv_setPrestige(tonumber(params[2]))
	elseif params[1] == "/settier" then
		ResearchManager.sv_setResearchTier(params[2])
	else
		params.player = player
		if sm.exists(player.character) then
			sm.event.sendToWorld(player.character:getWorld(), "sv_e_onChatCommand", params)
		end
	end
end

function FactoryGame.sv_giveItem(self, params)
	sm.container.beginTransaction()
	sm.container.collect(params.player:getInventory(), params.item, params.quantity, false)
	sm.container.endTransaction()
end

function FactoryGame.sv_reloadCell(self, params, player)
	print("sv_reloadCell Reloading cell at {" .. params.x .. " : " .. params.y .. "}")

	self.sv.saved.world:loadCell(params.x, params.y, player)
	self.network:sendToClients("cl_reloadCell", params)
end

function FactoryGame.sv_updateClientData(self)
	self.network:setClientData({ time = self.sv.time }, 2)
end

function FactoryGame.sv_switchGodMode(self)
	g_godMode = not g_godMode
	self.network:sendToClients("cl_chatMessage", "GODMODE: " .. (g_godMode and "On" or "Off"))
end

function FactoryGame.sv_n_switchAggroMode(self, params)
	sm.game.setEnableAggro(params.aggroMode)
	self.network:sendToClients("cl_chatMessage", "AGGRO: " .. (params.aggroMode and "On" or "Off"))
end

function FactoryGame.sv_enableRestrictions(self, state)
	sm.game.setEnableRestrictions(state)
	self.network:sendToClients("cl_chatMessage", (state and "Restricted" or "Unrestricted"))
end

function FactoryGame.sv_setLimitedInventory(self, state)
	sm.game.setLimitedInventory(state)
	self.network:sendToClients("cl_chatMessage", (state and "Limited inventory" or "Unlimited inventory"))
end

function FactoryGame.sv_setTimeOfDay(self, timeOfDay)
	if timeOfDay then
		self.sv.time.timeOfDay = timeOfDay
		---@diagnostic disable-next-line: undefined-field
		self.sv.syncTimer.count = self.sv.syncTimer.ticks -- Force sync
	end
	self.network:sendToClients("cl_chatMessage", ("Time of day set to " .. self.sv.time.timeOfDay))
end

function FactoryGame.sv_setTimeProgress(self, timeProgress)
	if timeProgress ~= nil then
		self.sv.time.timeProgress = timeProgress
		---@diagnostic disable-next-line: undefined-field
		self.sv.syncTimer.count = self.sv.syncTimer.ticks -- Force sync
	end
	self.network:sendToClients("cl_chatMessage",
		("Time scale set to " .. (self.sv.time.timeProgress and "on" or "off ")))
end

function FactoryGame.sv_killPlayer(self, params)
	params.damage = 6969
	sm.event.sendToPlayer(params.player, "sv_e_receiveDamage", params)
end

function FactoryGame.sv_spawnUnit(self, params)
	sm.event.sendToWorld(params.world, "sv_e_spawnUnit", params)
end

function FactoryGame.sv_spawnHarvestable(self, params)
	sm.event.sendToWorld(params.world, "sv_spawnHarvestable", params)
end

-- #endregion

---recreates the world, clears inventory too
function FactoryGame.sv_recreateWorld(self)
	self.sv.saved.data.seed = math.floor(math.random() * 10 ^ 9)

	self.sv.saved.world:destroy()
	self.sv.saved.world = sm.world.createWorld("$CONTENT_DATA/Scripts/game/FactoryWorld.lua", "FactoryWorld",
		{ dev = self.sv.saved.data.dev }, self.sv.saved.data.seed)
	g_world = self.sv.saved.world
	g_respawnManager:sv_setWorld(g_world)
	self.storage:save(self.sv.saved)

	for _, player in ipairs(sm.player.getAllPlayers()) do
		self:server_onPlayerJoined(player, true)
	end
end

---trigger a raid on the factory WIP
function FactoryGame:sv_factoryRaid()
	print("CUSTOM RAID")
	local level = 1
	local wave = 1
	local hours = 12

	sm.event.sendToWorld(self.sv.saved.world, "sv_raid", { level = level, wave = wave, hours = hours })
end

---show a `displayAlertText()` based on `LanguageManager.language_tag(tag)`
---@param params table tag = language tag; player = specific player or all players if nil
function FactoryGame:sv_e_showTagMessage(params)
	if params.player then
		self.network:sendToClient(params.player, "cl_localizedChatMessage", params.tag)
	else
		self.network:sendToClients("cl_localizedChatMessage", params.tag)
	end
end

---load saved data form self.storage.load()
function FactoryGame:sv_loadSavedData()
	self.sv.saved = self.storage:load()
	print("Saved:", self.sv.saved)

	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.data = self.data
		self.sv.saved.world = sm.world.createWorld("$CONTENT_DATA/Scripts/game/FactoryWorld.lua", "FactoryWorld",
			{ dev = self.sv.saved.data.dev }, self.sv.saved.data.seed)
		self:sv_e_setSpawnPoint(sm.vec3.new(0, 0, 20))
	elseif self.sv.saved.spawn then
		SPAWN_POINT = self.sv.saved.spawn
	end

	self.data = nil

	if (self.sv.saved.data and self.sv.saved.data.dev) then
		g_godMode = true
		g_survivalDev = true
		sm.log.info("Starting FactoryGame in DEV mode")
	end
end

---init manager objects
function FactoryGame:sv_initManagers()
	--vanila
	g_eventManager = EventManager()
	g_eventManager:sv_onCreate()

	g_respawnManager = RespawnManager()
	g_respawnManager:sv_onCreate(self.sv.saved.world)

	g_beaconManager = BeaconManager()
	g_beaconManager:sv_onCreate()

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate(self.sv.saved.world)

	--not saved
	local managers = {
		"c46b4d61-9f79-4f1c-b5d4-5ec4fff2c7b0", --languageManager
		"963f193f-cce8-4ed0-a04d-530fd70b230f" --lootCrateManager
	}

	for _, uuid in ipairs(managers) do
		sm.scriptableObject.createScriptableObject(sm.uuid.new(uuid))
	end

	--saved
	local savedManagers = {
		{ moneyManager = "e97b0595-7912-425b-8a60-ea6dbfba4b39" },
		{ powerManager = "26ec01d5-6fc8-4088-b06b-25d30dd44309" },
		{ researchManager = "6e7f54bb-e54d-46df-920a-bd225d0a9430" },
		{ pollutionManager = "64987a78-5b2b-4267-aeed-3d98dddcf12e" },
		{ prestigeManager = "2474d490-4530-4ff8-9436-ba716a0c665e" },
		{ perkManager = "35492036-d286-4b0f-a17c-efa228875c0d" },
		{ dailyRewardManager = "d0bed7e0-7065-40a5-b246-9f7356856037" },
		{ tutorialManager = "60702ca7-2d19-4d08-81e6-7a3ded53e338" }
	}
	local STORAGE_CHANNEL_FACTORY = 69

	for _, manager in ipairs(savedManagers) do
		for name, uuid in pairs(manager) do
			print(name, uuid)
			self.sv[name] = sm.storage.load(STORAGE_CHANNEL_FACTORY)
			if not self.sv[name] then
				self.sv[name] = sm.scriptableObject.createScriptableObject(sm.uuid.new(uuid))
				sm.storage.save(STORAGE_CHANNEL_FACTORY, self.sv[name])
			end
			STORAGE_CHANNEL_FACTORY = STORAGE_CHANNEL_FACTORY + 1
		end
	end
end

---vanila time syncing stuff
function FactoryGame:sv_initTimeSync()
	self.sv.time = sm.storage.load(STORAGE_CHANNEL_TIME)
	if self.sv.time then
		print("Loaded timeData:")
		print(self.sv.time)
	else
		self.sv.time = {}
		self.sv.time.timeOfDay = 6 / 24 -- 06:00
		self.sv.time.timeProgress = true
		sm.storage.save(STORAGE_CHANNEL_TIME, self.sv.time)
	end
	self.network:setClientData({ dev = g_survivalDev }, 1)
	self:sv_updateClientData()

	self.sv.syncTimer = Timer()
	---@diagnostic disable-next-line: undefined-field
	self.sv.syncTimer:start(0)
end

---fixed update vanila time stuff blah blah
function FactoryGame:sv_updateTimeStuff(timeStep)
	local prevTime = self.sv.time.timeOfDay
	if self.sv.time.timeProgress then
		self.sv.time.timeOfDay = self.sv.time.timeOfDay + timeStep / DAYCYCLE_TIME
	end
	local newDay = self.sv.time.timeOfDay >= 1.0
	if newDay then
		self.sv.time.timeOfDay = math.fmod(self.sv.time.timeOfDay, 1)
		self:sv_factoryRaid() --FACTORY
	end

	if self.sv.time.timeOfDay >= DAYCYCLE_DAWN and prevTime < DAYCYCLE_DAWN then
		g_unitManager:sv_initNewDay()
	end

	-- Client and save sync
	---@diagnostic disable-next-line: undefined-field
	self.sv.syncTimer:tick()
	---@diagnostic disable-next-line: undefined-field
	if self.sv.syncTimer:done() then
		---@diagnostic disable-next-line: undefined-field
		self.sv.syncTimer:start(SyncInterval)
		sm.storage.save(STORAGE_CHANNEL_TIME, self.sv.time)
	end
end

-- #endregion

--------------------
-- #region Client
--------------------

function FactoryGame.client_onCreate(self)
	self.cl = {
		time = {
			timeOfDay = 0.0,
			timeProgress = true
		}
	}

	g_shop = unpackNetworkData(sm.json.open("$CONTENT_DATA/Scripts/shop.json"))
	g_enableCollisionTumble = not sm.isHost or g_enableCollisionTumble

	-- managers
	g_respawnManager = g_respawnManager or RespawnManager()
	g_beaconManager = g_beaconManager or BeaconManager()
	g_unitManager = g_unitManager or UnitManager()
	g_unitManager:cl_onCreate()
	g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()

	-- Music effect
	g_survivalMusic = sm.effect.createEffect("SurvivalMusic")
	assert(g_survivalMusic)

	-- Survival HUD
	g_survivalHud = sm.gui.createSurvivalHudGui()
	g_survivalHud:setImage("LogbookImageBox", "$CONTENT_DATA/Gui/Images/shop.png")
	assert(g_survivalHud)

	-- Factory HUD
	g_factoryHud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ScrapFactory_Hud.layout", false,
		{ isHud = true, isInteractive = false, needsCursor = false })
	g_factoryHud:open()
end

function FactoryGame.cl_bindChatCommands(self)
	if g_survivalDev then
		-- custom
		sm.game.bindChatCommand("/addmoney", { { "string", "money", false } }, "cl_onChatCommand", "Gives moni")
		sm.game.bindChatCommand("/setmoney", { { "string", "money", false } }, "cl_onChatCommand", "Sets moni")
		sm.game.bindChatCommand("/addpollution", { { "string", "pollutuion", false } }, "cl_onChatCommand",
			"Gives pollutiion")
		sm.game.bindChatCommand("/setpollution", { { "string", "pollutuion", false } }, "cl_onChatCommand",
			"Sets pollutiion")
		sm.game.bindChatCommand("/addprestige", { { "string", "pollutuion", false } }, "cl_onChatCommand",
			"Gives prestige")
		sm.game.bindChatCommand("/setprestige", { { "string", "pollutuion", false } }, "cl_onChatCommand",
			"Sets prestige")
		sm.game.bindChatCommand("/give", { { "string", "uuid", false }, { "number", "quantity", true } },
			"cl_onChatCommand",
			"Gives an item by its uuid")
		sm.game.bindChatCommand("/settier", { { "int", "tier", false } }, "cl_onChatCommand",
			"Sets the research tier to this level")

		-- vanila
		sm.game.bindChatCommand("/god", {}, "cl_onChatCommand", "Mechanic characters will take no damage")
		sm.game.bindChatCommand("/respawn", {}, "cl_onChatCommand", "Respawn at last bed (or at the crash site)")
		sm.game.bindChatCommand("/encrypt", {}, "cl_onChatCommand", "Restrict interactions")
		sm.game.bindChatCommand("/decrypt", {}, "cl_onChatCommand", "Unrestrict interactions")
		sm.game.bindChatCommand("/limited", {}, "cl_onChatCommand", "Use the limited inventory")
		sm.game.bindChatCommand("/unlimited", {}, "cl_onChatCommand", "Use the unlimited inventory")
		sm.game.bindChatCommand("/timeofday", { { "number", "timeOfDay", true } }, "cl_onChatCommand",
			"Sets the time of the day as a fraction (0.5=mid day)")
		sm.game.bindChatCommand("/timeprogress", { { "bool", "enabled", true } }, "cl_onChatCommand",
			"Enables or disables time progress")
		sm.game.bindChatCommand("/day", {}, "cl_onChatCommand", "Disable time progression and set time to daytime")
		sm.game.bindChatCommand("/spawn", { { "string", "unitName", true }, { "int", "amount", true } },
			"cl_onChatCommand",
			"Spawn a unit: 'woc', 'tapebot', 'totebot', 'haybot'")
		sm.game.bindChatCommand("/harvestable", { { "string", "harvestableName", true } }, "cl_onChatCommand",
			"Create a harvestable: 'tree', 'stone'")
		sm.game.bindChatCommand("/die", {}, "cl_onChatCommand", "Kill the player")
		sm.game.bindChatCommand("/sethp", { { "number", "hp", false } }, "cl_onChatCommand", "Set player hp value")
		sm.game.bindChatCommand("/aggroall", {}, "cl_onChatCommand",
			"All hostile units will be made aware of the player's position")
		sm.game.bindChatCommand("/raid",
			{ { "int", "level", false }, { "int", "wave", true }, { "number", "hours", true } },
			"cl_onChatCommand", "Start a level <level> raid at player position at wave <wave> in <delay> hours.")
		sm.game.bindChatCommand("/stopraid", {}, "cl_onChatCommand", "Cancel all incoming raids")
		sm.game.bindChatCommand("/camera", {}, "cl_onChatCommand", "Spawn a SplineCamera tool")
		sm.game.bindChatCommand("/noaggro", { { "bool", "enable", true } }, "cl_onChatCommand",
			"Toggles the player as a target")
		sm.game.bindChatCommand("/killall", {}, "cl_onChatCommand", "Kills all spawned units")
		sm.game.bindChatCommand("/printglobals", {}, "cl_onChatCommand", "Print all global lua variables")
	end
end

function FactoryGame.client_onClientDataUpdate(self, clientData, channel)
	if channel == 2 then
		self.cl.time = clientData.time
	elseif channel == 1 then
		g_survivalDev = clientData.dev
		self:cl_bindChatCommands()
	end
end

function FactoryGame.client_onUpdate(self, dt)
	-- Update time
	if self.cl.time.timeProgress then
		self.cl.time.timeOfDay = math.fmod(self.cl.time.timeOfDay + dt / DAYCYCLE_TIME, 1.0)
	end
	sm.game.setTimeOfDay(self.cl.time.timeOfDay)

	-- Update lighting values
	local index = 1
	while index < #DAYCYCLE_LIGHTING_TIMES and self.cl.time.timeOfDay >= DAYCYCLE_LIGHTING_TIMES[index + 1] do
		index = index + 1
	end
	assert(index <= #DAYCYCLE_LIGHTING_TIMES)

	local light = 0.0
	if index < #DAYCYCLE_LIGHTING_TIMES then
		local p = (self.cl.time.timeOfDay - DAYCYCLE_LIGHTING_TIMES[index]) /
			(DAYCYCLE_LIGHTING_TIMES[index + 1] - DAYCYCLE_LIGHTING_TIMES[index])
		light = sm.util.lerp(DAYCYCLE_LIGHTING_VALUES[index], DAYCYCLE_LIGHTING_VALUES[index + 1], p)
	else
		light = DAYCYCLE_LIGHTING_VALUES[index]
	end
	sm.render.setOutdoorLighting(light)
end

---show a chatMessage to a client
---@param self FactoryGame
---@param msg string
function FactoryGame.cl_chatMessage(self, msg)
	sm.gui.chatMessage(msg)
end

function FactoryGame.cl_onChatCommand(self, params)
	local unitSpawnNames =
	{
		woc = unit_woc,
		tapebot = unit_tapebot,
		tb = unit_tapebot,
		redtapebot = unit_tapebot_red,
		rtb = unit_tapebot_red,
		totebot = unit_totebot_green,
		green = unit_totebot_green,
		t = unit_totebot_green,
		totered = unit_totebot_red,
		red = unit_totebot_red,
		tr = unit_totebot_red,
		haybot = unit_haybot,
		h = unit_haybot,
		worm = unit_worm,
		farmbot = unit_farmbot,
		f = unit_farmbot,
	}

	if params[1] == "/camera" then
		self.network:sendToServer("sv_giveItem",
			{
				player = sm.localPlayer.getPlayer(),
				item = sm.uuid.new("5bbe87d3-d60a-48b5-9ca9-0086c80ebf7f"),
				quantity = 1
			})
	elseif params[1] == "/god" then
		self.network:sendToServer("sv_switchGodMode")
	elseif params[1] == "/encrypt" then
		self.network:sendToServer("sv_enableRestrictions", true)
	elseif params[1] == "/decrypt" then
		self.network:sendToServer("sv_enableRestrictions", false)
	elseif params[1] == "/unlimited" then
		self.network:sendToServer("sv_setLimitedInventory", false)
	elseif params[1] == "/limited" then
		self.network:sendToServer("sv_setLimitedInventory", true)
	elseif params[1] == "/timeofday" then
		self.network:sendToServer("sv_setTimeOfDay", params[2])
	elseif params[1] == "/timeprogress" then
		self.network:sendToServer("sv_setTimeProgress", params[2])
	elseif params[1] == "/day" then
		self.network:sendToServer("sv_setTimeOfDay", 0.5)
		self.network:sendToServer("sv_setTimeProgress", false)
	elseif params[1] == "/die" then
		self.network:sendToServer("sv_killPlayer", { player = sm.localPlayer.getPlayer() })
	elseif params[1] == "/spawn" then
		local rayCastValid, rayCastResult = sm.localPlayer.getRaycast(100)
		if rayCastValid then
			local spawnParams = {
				uuid = sm.uuid.getNil(),
				world = sm.localPlayer.getPlayer().character:getWorld(),
				position = rayCastResult.pointWorld,
				yaw = 0.0,
				amount = 1
			}
			if unitSpawnNames[params[2]] then
				spawnParams.uuid = unitSpawnNames[params[2]]
			else
				spawnParams.uuid = sm.uuid.new(params[2])
			end
			if params[3] then
				spawnParams.amount = params[3]
			end
			self.network:sendToServer("sv_spawnUnit", spawnParams)
		end
	elseif params[1] == "/harvestable" then
		local character = sm.localPlayer.getPlayer().character
		if character then
			local harvestableUuid = sm.uuid.getNil()
			if params[2] == "tree" then
				harvestableUuid = sm.uuid.new("c4ea19d3-2469-4059-9f13-3ddb4f7e0b79")
			elseif params[2] == "stone" then
				harvestableUuid = sm.uuid.new("0d3362ae-4cb3-42ae-8a08-d3f9ed79e274")
			elseif params[2] == "soil" then
				harvestableUuid = hvs_soil
			elseif params[2] == "fencelong" then
				harvestableUuid = sm.uuid.new("c0f19413-6d8e-4b20-819a-949553242259")
			elseif params[2] == "fenceshort" then
				harvestableUuid = sm.uuid.new("144b5e79-483e-4da6-86ab-c575d0fdcd11")
			elseif params[2] == "fencecorner" then
				harvestableUuid = sm.uuid.new("ead875db-59d0-45f5-861e-b3075e1f8434")
			elseif params[2] == "beehive" then
				harvestableUuid = hvs_farmables_beehive
			elseif params[2] == "cotton" then
				harvestableUuid = hvs_farmables_cottonplant
			elseif params[2] then
				harvestableUuid = sm.uuid.new(params[2])
			end
			local spawnParams = {
				world = character:getWorld(),
				uuid = harvestableUuid,
				position = character.worldPosition,
				quat = sm.vec3.getRotation(sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1))
			}
			self.network:sendToServer("sv_spawnHarvestable", spawnParams)
		end
	elseif params[1] == "/cleardebug" then
		sm.debugDraw.clear()
	elseif params[1] == "/noaggro" then
		if type(params[2]) == "boolean" then
			self.network:sendToServer("sv_n_switchAggroMode", { aggroMode = not params[2] })
		else
			self.network:sendToServer("sv_n_switchAggroMode", { aggroMode = not sm.game.getEnableAggro() })
		end
	elseif params[1] == "/give" then
		self.network:sendToServer("sv_giveItem",
			{
				player = sm.localPlayer.getPlayer(),
				item = sm.uuid.new(params[2]),
				quantity = params[3] or 1
			})
	else
		self.network:sendToServer("sv_onChatCommand", params)
	end
end

function FactoryGame.cl_reloadCell(self, params)
	print("cl_reloadCell reloading " .. params.x .. " : " .. params.y)
	for x = -2, 2 do
		for y = -2, 2 do
			params.world:reloadCell(params.x + x, params.y + y, "cl_reloadCellTestCallback")
		end
	end
end

function FactoryGame.client_onLoadingScreenLifted(self)
	g_effectManager:cl_onLoadingScreenLifted()

	PowerManager.cl_setloadTick(sm.game.getCurrentTick())
	UnitManager.cl_setloadTick(g_unitManager, sm.game.getCurrentTick())
end

---show a displayAlert to a client
---@param self FactoryGame
---@param msg string
function FactoryGame:cl_displayAlert(msg)
	sm.gui.displayAlertText(msg)
end

---show a localized chatMessage to a client
---@param self FactoryGame
---@param tag string localization tag for `language_tag()`
function FactoryGame:cl_localizedChatMessage(tag)
	sm.gui.displayAlertText(language_tag(tag))
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class FactoryGameSv
---@field saved FactoryGameSvSaved
---@field time FactoryGameTime
---@diagnostic disable-next-line: undefined-doc-name
---@field syncTimer Timer

---@class FactoryGameSvSaved
---@field world World the game world saved
---@field data FactoryGameSvSavedData
---@field spawn Vec3 the saved spawnopoint

---@class FactoryGameSvSavedData
---@field dev boolean whether the game is in devmode
---@field seed number the world seed

---@class FactoryGameTime
---@field timeOfday number
---@field timeProgress boolean

---@class FactoryGameCl
---@field time FactoryGameTime

-- #endregion
