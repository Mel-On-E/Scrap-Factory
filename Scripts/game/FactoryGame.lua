dofile("$SURVIVAL_DATA/Scripts/game/managers/BeaconManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/ElevatorManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/RespawnManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/UnitManager.lua") --FACTORY
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua")
dofile("$SURVIVAL_DATA/Scripts/game/util/recipes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/util/Timer.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/QuestEntityManager.lua")
dofile("$GAME_DATA/Scripts/game/managers/EventManager.lua")

dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/util/uuids.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/MoneyManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PowerManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/ResearchManager.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LootCrateManager.lua")



---@class FactoryGame : GameClass
---@field sv table
---@field cl table
---@field warehouses table
FactoryGame = class(nil)
FactoryGame.enableLimitedInventory = true
FactoryGame.enableRestrictions = true
FactoryGame.enableFuelConsumption = false
FactoryGame.enableAmmoConsumption = false
FactoryGame.enableUpgrade = true
FactoryGame.defaultInventorySize = 1024

local SyncInterval = 400 -- 400 ticks | 10 seconds
local IntroFadeDuration = 1.1
local IntroEndFadeDuration = 1.1
local IntroFadeTimeout = 5.0

SURVIVAL_DEV_SPAWN_POINT = sm.vec3.new(0, 0, 20)
START_AREA_SPAWN_POINT = sm.vec3.new(0, 0, 20)

local STORAGE_CHANNEL_MONEYMANAGER = 69
local STORAGE_CHANNEL_POWERMANAGER = 70
local STORAGE_CHANNEL_RESEARCHMANAGER = 71
local STORAGE_CHANNEL_DAILYREWARDMANAGER = 72
local STORAGE_CHANNEL_POLLUTIONMANAGER = 73

function FactoryGame.server_onCreate(self)
	print("FactoryGame.server_onCreate")
	self.sv = {}
	self.sv.saved = self.storage:load()
	print("Saved:", self.sv.saved)
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.data = self.data
		printf("Seed: %.0f", self.sv.saved.data.seed)
		self.sv.saved.overworld = sm.world.createWorld("$CONTENT_DATA/Scripts/game/Overworld.lua", "Overworld",
			{ dev = self.sv.saved.data.dev }, self.sv.saved.data.seed)
		self.storage:save(self.sv.saved)
	end
	self.data = nil


	--FACTORY
	self.sv.factory = {}

	print(self.sv.saved.data)
	if self.sv.saved.data and self.sv.saved.data.dev then
		g_godMode = true
		g_survivalDev = true
		sm.log.info("Starting FactoryGame in DEV mode")
	end

	self:loadCraftingRecipes()
	g_enableCollisionTumble = true

	g_eventManager = EventManager()
	g_eventManager:sv_onCreate()

	g_elevatorManager = ElevatorManager()
	g_elevatorManager:sv_onCreate()






	g_respawnManager = RespawnManager()
	g_respawnManager:sv_onCreate(self.sv.saved.overworld)

	g_beaconManager = BeaconManager()
	g_beaconManager:sv_onCreate()

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate(self.sv.saved.overworld)

	self.sv.questEntityManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("c6988ecb-0fc1-4d45-afde-dc583b8b75ee"))

	self.sv.questManager = sm.storage.load(STORAGE_CHANNEL_QUESTMANAGER)
	if not self.sv.questManager then
		self.sv.questManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("83b0cc7e-b164-47b8-a83c-0d33ba5f72ec"))
		sm.storage.save(STORAGE_CHANNEL_QUESTMANAGER, self.sv.questManager)
	end





	-- Game script managed global warehouse table
	self.sv.warehouses = sm.storage.load(STORAGE_CHANNEL_WAREHOUSES)
	if self.sv.warehouses then
		print("Loaded warehouses:")
		print(self.sv.warehouses)
	else
		self.sv.warehouses = {}
		sm.storage.save(STORAGE_CHANNEL_WAREHOUSES, self.sv.warehouses)
	end












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
	self.sv.syncTimer:start(0)

	--FACTORY
	local languageManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("c46b4d61-9f79-4f1c-b5d4-5ec4fff2c7b0"))
	local lootCrateManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("963f193f-cce8-4ed0-a04d-530fd70b230f"))
	LootCrateManager.sv_setWorld(self.sv.saved.overworld)

	self.sv.moneyManager = sm.storage.load(STORAGE_CHANNEL_MONEYMANAGER)
	if not self.sv.moneyManager then
		self.sv.moneyManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("e97b0595-7912-425b-8a60-ea6dbfba4b39"))
		sm.storage.save(STORAGE_CHANNEL_MONEYMANAGER, self.sv.moneyManager)
	end

	self.sv.powerManager = sm.storage.load(STORAGE_CHANNEL_POWERMANAGER)
	if not self.sv.powerManager then
		self.sv.powerManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("26ec01d5-6fc8-4088-b06b-25d30dd44309"))
		sm.storage.save(STORAGE_CHANNEL_POWERMANAGER, self.sv.powerManager)
	end

	self.sv.researchManager = sm.storage.load(STORAGE_CHANNEL_RESEARCHMANAGER)
	if not self.sv.researchManager then
		self.sv.researchManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("6e7f54bb-e54d-46df-920a-bd225d0a9430"))
		sm.storage.save(STORAGE_CHANNEL_RESEARCHMANAGER, self.sv.researchManager)
	end

	self.sv.pollutionManager = sm.storage.load(STORAGE_CHANNEL_POLLUTIONMANAGER)
	if not self.sv.pollutionManager then
		self.sv.pollutionManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("64987a78-5b2b-4267-aeed-3d98dddcf12e"))
		sm.storage.save(STORAGE_CHANNEL_POLLUTIONMANAGER, self.sv.pollutionManager)
	end

	self.sv.dailyReawardManager = sm.storage.load(STORAGE_CHANNEL_DAILYREWARDMANAGER)
	if not self.sv.dailyReawardManager then
		self.sv.dailyReawardManager = sm.scriptableObject.createScriptableObject(sm.uuid.new("d0bed7e0-7065-40a5-b246-9f7356856037"))
		sm.storage.save(STORAGE_CHANNEL_DAILYREWARDMANAGER, self.sv.dailyReawardManager)
	end
end

function FactoryGame.server_onRefresh(self)
	g_craftingRecipes = nil
	g_refineryRecipes = nil
	self:loadCraftingRecipes()
end

function FactoryGame.client_onCreate(self)

	self.cl = {}
	self.cl.time = {}
	self.cl.time.timeOfDay = 0.0
	self.cl.time.timeProgress = true

	if not sm.isHost then
		self:loadCraftingRecipes()
		g_enableCollisionTumble = true
	end

	if g_respawnManager == nil then
		assert(not sm.isHost)
		g_respawnManager = RespawnManager()
	end
	g_respawnManager:cl_onCreate()

	if g_beaconManager == nil then
		assert(not sm.isHost)
		g_beaconManager = BeaconManager()
	end
	g_beaconManager:cl_onCreate()

	if g_unitManager == nil then
		assert(not sm.isHost)
		g_unitManager = UnitManager()
	end
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

	--FACTORY
	g_factoryHud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ScrapFactory_Hud.layout", false,
		{ isHud = true, isInteractive = false, needsCursor = false })
	g_factoryHud:open()

	g_shop = sm.json.open("$CONTENT_DATA/Scripts/shop.json")
	for _, item in pairs(g_shop) do
		item.price = tonumber(item.price)
	end
end

function FactoryGame.bindChatCommands(self)
	local addCheats = g_survivalDev

	if addCheats then
		sm.game.bindChatCommand("/giveMoney", { { "string", "money", false } }, "cl_onChatCommand", "Gives moni")
		sm.game.bindChatCommand("/setmoney", { { "string", "money", false } }, "cl_onChatCommand", "Sets moni")

		sm.game.bindChatCommand("/addpollution", { { "string", "pollutuion", false } }, "cl_onChatCommand", "Gives pollutiion")
		sm.game.bindChatCommand("/setpollution", { { "string", "pollutuion", false } }, "cl_onChatCommand", "Sets pollutiion")


		sm.game.bindChatCommand("/test", {}, "cl_onChatCommand", "does test")
		
		sm.game.bindChatCommand("/god", {}, "cl_onChatCommand", "Mechanic characters will take no damage")
		sm.game.bindChatCommand("/respawn", {}, "cl_onChatCommand", "Respawn at last bed (or at the crash site)")
		sm.game.bindChatCommand("/encrypt", {}, "cl_onChatCommand", "Restrict interactions in all warehouses")
		sm.game.bindChatCommand("/decrypt", {}, "cl_onChatCommand", "Unrestrict interactions in all warehouses")
		sm.game.bindChatCommand("/limited", {}, "cl_onChatCommand", "Use the limited inventory")
		sm.game.bindChatCommand("/unlimited", {}, "cl_onChatCommand", "Use the unlimited inventory")
		--sm.game.bindChatCommand( "/recreate", {}, "cl_onChatCommand", "Recreate world" )
		sm.game.bindChatCommand("/timeofday", { { "number", "timeOfDay", true } }, "cl_onChatCommand",
			"Sets the time of the day as a fraction (0.5=mid day)")
		sm.game.bindChatCommand("/timeprogress", { { "bool", "enabled", true } }, "cl_onChatCommand",
			"Enables or disables time progress")
		sm.game.bindChatCommand("/day", {}, "cl_onChatCommand", "Disable time progression and set time to daytime")
		sm.game.bindChatCommand("/spawn", { { "string", "unitName", true }, { "int", "amount", true } }, "cl_onChatCommand",
			"Spawn a unit: 'woc', 'tapebot', 'totebot', 'haybot'")
		sm.game.bindChatCommand("/harvestable", { { "string", "harvestableName", true } }, "cl_onChatCommand",
			"Create a harvestable: 'tree', 'stone'")
		sm.game.bindChatCommand("/export", { { "string", "name", false } }, "cl_onChatCommand",
			"Exports blueprint $SURVIVAL_DATA/LocalBlueprints/<name>.blueprint")
		sm.game.bindChatCommand("/import", { { "string", "name", false } }, "cl_onChatCommand",
			"Imports blueprint $SURVIVAL_DATA/LocalBlueprints/<name>.blueprint")
		sm.game.bindChatCommand("/die", {}, "cl_onChatCommand", "Kill the player")
		sm.game.bindChatCommand("/sethp", { { "number", "hp", false } }, "cl_onChatCommand", "Set player hp value")
		sm.game.bindChatCommand("/aggroall", {}, "cl_onChatCommand",
			"All hostile units will be made aware of the player's position")
		sm.game.bindChatCommand("/raid", { { "int", "level", false }, { "int", "wave", true }, { "number", "hours", true } },
			"cl_onChatCommand", "Start a level <level> raid at player position at wave <wave> in <delay> hours.")
		sm.game.bindChatCommand("/stopraid", {}, "cl_onChatCommand", "Cancel all incoming raids")
		sm.game.bindChatCommand("/disableraids", { { "bool", "enabled", false } }, "cl_onChatCommand", "Disable raids if true")
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
		self:bindChatCommands()
	end
end

function FactoryGame.loadCraftingRecipes(self)
	LoadCraftingRecipes({
		workbench = "$SURVIVAL_DATA/CraftingRecipes/workbench.json",
		dispenser = "$SURVIVAL_DATA/CraftingRecipes/dispenser.json",
		cookbot = "$SURVIVAL_DATA/CraftingRecipes/cookbot.json",
		craftbot = "$SURVIVAL_DATA/CraftingRecipes/craftbot.json",
		dressbot = "$SURVIVAL_DATA/CraftingRecipes/dressbot.json"
	})
end

function FactoryGame.server_onFixedUpdate(self, timeStep)
	-- Update time

	local prevTime = self.sv.time.timeOfDay
	if self.sv.time.timeProgress then
		self.sv.time.timeOfDay = self.sv.time.timeOfDay + timeStep / DAYCYCLE_TIME
	end
	local newDay = self.sv.time.timeOfDay >= 1.0
	if newDay then
		self.sv.time.timeOfDay = math.fmod(self.sv.time.timeOfDay, 1)
		--FACTORY
		self:sv_factoryRaid()
	end

	if self.sv.time.timeOfDay >= DAYCYCLE_DAWN and prevTime < DAYCYCLE_DAWN then
		g_unitManager:sv_initNewDay()
	end

	-- Ambush
	--if not g_survivalDev then
	--	for _,ambush in ipairs( AMBUSHES ) do
	--		if self.sv.time.timeOfDay >= ambush.time and ( prevTime < ambush.time or newDay ) then
	--			self:sv_ambush( { magnitude = ambush.magnitude, wave = ambush.wave } )
	--		end
	--	end
	--end

	-- Client and save sync
	self.sv.syncTimer:tick()
	if self.sv.syncTimer:done() then
		self.sv.syncTimer:start(SyncInterval)
		sm.storage.save(STORAGE_CHANNEL_TIME, self.sv.time)
	end

	g_elevatorManager:sv_onFixedUpdate()

	g_unitManager:sv_onFixedUpdate()
	if g_eventManager then
		g_eventManager:sv_onFixedUpdate()
	end

	--factory
	if sm.game.getCurrentTick() % 40 == 0 then
		self:sv_updateClientData()
	end
end

function FactoryGame.sv_updateClientData(self)
	self.network:setClientData({ time = self.sv.time }, 2)
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

function FactoryGame.client_showMessage(self, msg)
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

	if params[1] == "/giveMoney" then
		self.network:sendToServer("sv_addMoney", params[2])
	elseif params[1] == "/setmoney" then
		self.network:sendToServer("sv_setMoney", params[2])
	elseif params[1] == "/test" then
		



	elseif params[1] == "/camera" then
		self.network:sendToServer("sv_giveItem",
			{ player = sm.localPlayer.getPlayer(), item = sm.uuid.new("5bbe87d3-d60a-48b5-9ca9-0086c80ebf7f"), quantity = 1 })
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
			local spawnParams = { world = character:getWorld(), uuid = harvestableUuid, position = character.worldPosition,
				quat = sm.vec3.getRotation(sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1)) }
			self.network:sendToServer("sv_spawnHarvestable", spawnParams)
		end
	elseif params[1] == "/cleardebug" then
		sm.debugDraw.clear()
	elseif params[1] == "/export" then
		local rayCastValid, rayCastResult = sm.localPlayer.getRaycast(100)
		if rayCastValid and rayCastResult.type == "body" then
			local importParams = {
				name = params[2],
				body = rayCastResult:getBody()
			}
			self.network:sendToServer("sv_exportCreation", importParams)
		end
	elseif params[1] == "/import" then
		local rayCastValid, rayCastResult = sm.localPlayer.getRaycast(100)
		if rayCastValid then
			local importParams = {
				world = sm.localPlayer.getPlayer().character:getWorld(),
				name = params[2],
				position = rayCastResult.pointWorld
			}
			self.network:sendToServer("sv_importCreation", importParams)
		end
	elseif params[1] == "/noaggro" then
		if type(params[2]) == "boolean" then
			self.network:sendToServer("sv_n_switchAggroMode", { aggroMode = not params[2] })
		else
			self.network:sendToServer("sv_n_switchAggroMode", { aggroMode = not sm.game.getEnableAggro() })
		end
	else
		self.network:sendToServer("sv_onChatCommand", params)
	end
end

function FactoryGame.sv_reloadCell(self, params, player)
	print("sv_reloadCell Reloading cell at {" .. params.x .. " : " .. params.y .. "}")

	self.sv.saved.overworld:loadCell(params.x, params.y, player)
	self.network:sendToClients("cl_reloadCell", params)
end

function FactoryGame.cl_reloadCell(self, params)
	print("cl_reloadCell reloading " .. params.x .. " : " .. params.y)
	for x = -2, 2 do
		for y = -2, 2 do
			params.world:reloadCell(params.x + x, params.y + y, "cl_reloadCellTestCallback")
		end
	end

end

function FactoryGame.cl_reloadCellTestCallback(self, world, x, y, result)
	print("cl_reloadCellTestCallback")
	print("result = " .. result)
end

function FactoryGame.sv_giveItem(self, params)
	sm.container.beginTransaction()
	sm.container.collect(params.player:getInventory(), params.item, params.quantity, false)
	sm.container.endTransaction()
end

function FactoryGame.cl_n_onJoined(self, params)
	self.cl.playIntroCinematic = params.newPlayer
end

function FactoryGame.client_onLoadingScreenLifted(self)
	g_effectManager:cl_onLoadingScreenLifted()
	self.network:sendToServer("sv_n_loadingScreenLifted")
	if self.cl.playIntroCinematic then
		local callbacks = {}
		callbacks[#callbacks + 1] = { fn = "cl_onCinematicEvent", params = { cinematicName = "cinematic.survivalstart01" },
			ref = self }
		g_effectManager:cl_playNamedCinematic("cinematic.survivalstart01", callbacks)
	end

	--FACTORY
	PowerManager.cl_setLoaded(sm.game.getCurrentTick())
	UnitManager.cl_setLoaded(g_unitManager, sm.game.getCurrentTick())
end

function FactoryGame.sv_n_loadingScreenLifted(self, _, player)
	if not g_survivalDev then
		QuestManager.Sv_TryActivateQuest("quest_tutorial")
	end
end

function FactoryGame.cl_onCinematicEvent(self, eventName, params)
	local myPlayer = sm.localPlayer.getPlayer()
	local myCharacter = myPlayer and myPlayer.character or nil
	if eventName == "survivalstart01.dramatics_standup" then
		if sm.exists(myCharacter) then
			sm.event.sendToCharacter(myCharacter, "cl_e_onEvent", "dramatics_standup")
		end
	elseif eventName == "survivalstart01.fadeout" then
		sm.event.sendToPlayer(myPlayer, "cl_e_startFadeToBlack", { duration = IntroFadeDuration, timeout = IntroFadeTimeout })
	elseif eventName == "survivalstart01.fadein" then
		sm.event.sendToPlayer(myPlayer, "cl_n_endFadeToBlack", { duration = IntroEndFadeDuration })
	end
end

function FactoryGame.sv_switchGodMode(self)
	g_godMode = not g_godMode
	self.network:sendToClients("client_showMessage", "GODMODE: " .. (g_godMode and "On" or "Off"))
end

function FactoryGame.sv_n_switchAggroMode(self, params)
	sm.game.setEnableAggro(params.aggroMode)
	self.network:sendToClients("client_showMessage", "AGGRO: " .. (params.aggroMode and "On" or "Off"))
end

function FactoryGame.sv_enableRestrictions(self, state)
	sm.game.setEnableRestrictions(state)
	self.network:sendToClients("client_showMessage", (state and "Restricted" or "Unrestricted"))
end

function FactoryGame.sv_setLimitedInventory(self, state)
	sm.game.setLimitedInventory(state)
	self.network:sendToClients("client_showMessage", (state and "Limited inventory" or "Unlimited inventory"))
end

function FactoryGame.sv_ambush(self, params)
	if sm.exists(self.sv.saved.overworld) then
		sm.event.sendToWorld(self.sv.saved.overworld, "sv_ambush", params)
	end
end

function FactoryGame.sv_setTimeOfDay(self, timeOfDay)
	if timeOfDay then
		self.sv.time.timeOfDay = timeOfDay
		self.sv.syncTimer.count = self.sv.syncTimer.ticks -- Force sync
	end
	self.network:sendToClients("client_showMessage", ("Time of day set to " .. self.sv.time.timeOfDay))
end

function FactoryGame.sv_setTimeProgress(self, timeProgress)
	if timeProgress ~= nil then
		self.sv.time.timeProgress = timeProgress
		self.sv.syncTimer.count = self.sv.syncTimer.ticks -- Force sync
	end
	self.network:sendToClients("client_showMessage",
		("Time scale set to " .. (self.sv.time.timeProgress and "on" or "off ")))
end

function FactoryGame.sv_killPlayer(self, params)
	params.damage = 9999
	sm.event.sendToPlayer(params.player, "sv_e_receiveDamage", params)
end

function FactoryGame.sv_spawnUnit(self, params)
	sm.event.sendToWorld(params.world, "sv_e_spawnUnit", params)
end

function FactoryGame.sv_spawnHarvestable(self, params)
	sm.event.sendToWorld(params.world, "sv_spawnHarvestable", params)
end

function FactoryGame.sv_exportCreation(self, params)
	local obj = sm.json.parseJsonString(sm.creation.exportToString(params.body))
	sm.json.save(obj, "$CONTENT_DATA/LocalBlueprints/" .. params.name .. ".blueprint")
end

function FactoryGame.sv_importCreation(self, params)
	sm.creation.importFromFile(params.world, "$SURVIVAL_DATA/LocalBlueprints/" .. params.name .. ".blueprint",
		params.position)
end

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
	elseif params[1] == "/addpollution" then
		PollutionManager.sv_addPollution(tonumber(params[2]))
	elseif params[1] == "/setpollution" then
		PollutionManager.sv_setPollution(tonumber(params[2]))

	else
		params.player = player
		if sm.exists(player.character) then
			sm.event.sendToWorld(player.character:getWorld(), "sv_e_onChatCommand", params)
		end
	end
end

function FactoryGame.server_onPlayerJoined(self, player, newPlayer)
	print(player.name, "joined the game")

	if newPlayer then --Player is first time joiners
		local inventory = player:getInventory()

		sm.container.beginTransaction()
		sm.container.setItem(inventory, 0, tool_hammer, 1)
		sm.container.setItem(inventory, 1, tool_lift, 1)
		sm.container.setItem(inventory, 2, sm.uuid.new("8c7efc37-cd7c-4262-976e-39585f8527bf"), 1) --connect tool
		sm.container.setItem(inventory, 3, tool_sell, 1)
		sm.container.setItem(inventory, 4, obj_dropper_scrap_wood, 1)
		sm.container.setItem(inventory, 5, obj_furnace_basic, 1)
		sm.container.setItem(inventory, 6, obj_generator_windmill, 1)
		sm.container.endTransaction()

		local spawnPoint = g_survivalDev and SURVIVAL_DEV_SPAWN_POINT or START_AREA_SPAWN_POINT
		if not sm.exists(self.sv.saved.overworld) then
			sm.world.loadWorld(self.sv.saved.overworld)
		end
		self.sv.saved.overworld:loadCell(math.floor(spawnPoint.x / 64), math.floor(spawnPoint.y / 64), player,
			"sv_createNewPlayer")
		self.network:sendToClient(player, "cl_n_onJoined", { newPlayer = newPlayer })
	else
		local inventory = player:getInventory()

		local tool_sledgehammer = sm.uuid.new("ed185725-ea12-43fc-9cd7-4295d0dbf88b")
		local sledgehammerCount = sm.container.totalQuantity(inventory, tool_sledgehammer)
		if sledgehammerCount == 0 then
			sm.container.beginTransaction()
			sm.container.collect(inventory, tool_sledgehammer, 1)
			sm.container.endTransaction()
		elseif sledgehammerCount > 1 then
			sm.container.beginTransaction()
			sm.container.spend(inventory, tool_sledgehammer, sledgehammerCount - 1)
			sm.container.endTransaction()
		end

		local tool_lift = sm.uuid.new("5cc12f03-275e-4c8e-b013-79fc0f913e1b")
		local liftCount = sm.container.totalQuantity(inventory, tool_lift)
		if liftCount == 0 then
			sm.container.beginTransaction()
			sm.container.collect(inventory, tool_lift, 1)
			sm.container.endTransaction()
		elseif liftCount > 1 then
			sm.container.beginTransaction()
			sm.container.spend(inventory, tool_lift, liftCount - 1)
			sm.container.endTransaction()
		end
	end
	if player.id > 1 then --Too early for self. Questmanager is not created yet...
		QuestManager.Sv_OnEvent(QuestEvent.PlayerJoined, { player = player })
	end
	g_unitManager:sv_onPlayerJoined(player)
end

function FactoryGame.server_onPlayerLeft(self, player)
	print(player.name, "left the game")
	if player.id > 1 then
		QuestManager.Sv_OnEvent(QuestEvent.PlayerLeft, { player = player })
	end
	g_elevatorManager:sv_onPlayerLeft(player)

end

function FactoryGame.sv_e_requestWarehouseRestrictions(self, params)
	-- Send the warehouse restrictions to the world that asked
	print("FactoryGame.sv_e_requestWarehouseRestrictions")

	-- Warehouse get
	local warehouse = nil
	if params.warehouseIndex then
		warehouse = self.sv.warehouses[params.warehouseIndex]
	end
	if warehouse then
		sm.event.sendToWorld(params.world, "server_updateRestrictions", warehouse.restrictions)
	end
end

function FactoryGame.sv_e_setWarehouseRestrictions(self, params)
	-- Set the restrictions for this warehouse and propagate the restrictions to all floors

	-- Warehouse get
	local warehouse = nil
	if params.warehouseIndex then
		warehouse = self.sv.warehouses[params.warehouseIndex]
	end

	if warehouse then
		for _, newRestrictionSetting in pairs(params.restrictions) do
			if warehouse.restrictions[newRestrictionSetting.name] then
				warehouse.restrictions[newRestrictionSetting.name].state = newRestrictionSetting.state
			else
				warehouse.restrictions[newRestrictionSetting.name] = newRestrictionSetting
			end
		end
		self.sv.warehouses[params.warehouseIndex] = warehouse
		sm.storage.save(STORAGE_CHANNEL_WAREHOUSES, self.sv.warehouses)

		for i, world in ipairs(warehouse.worlds) do
			if sm.exists(world) then
				sm.event.sendToWorld(world, "server_updateRestrictions", warehouse.restrictions)
			end
		end
	end
end

function FactoryGame.sv_e_createElevatorDestination(self, params)
	print("FactoryGame.sv_e_createElevatorDestination")
	print(params)

	-- Warehouse get or create
	local warehouse
	if params.warehouseIndex then
		warehouse = self.sv.warehouses[params.warehouseIndex]
	else
		assert(params.name == "ELEVATOR_ENTRANCE")
		warehouse = {}
		warehouse.test = params.test
		warehouse.world = params.portal:getWorldA()
		warehouse.worlds = {}
		warehouse.exits = params.exits
		warehouse.maxLevels = params.maxLevels
		warehouse.index = #self.sv.warehouses + 1
		warehouse.restrictions = { erasable = { name = "erasable", state = false },
			connectable = { name = "connectable", state = false } }
		self.sv.warehouses[#self.sv.warehouses + 1] = warehouse
		sm.storage.save(STORAGE_CHANNEL_WAREHOUSES, self.sv.warehouses)
	end


	-- Level up
	local level
	if params.level then
		if params.name == "ELEVATOR_UP" then
			level = params.level + 1
		elseif params.name == "ELEVATOR_DOWN" then
			level = params.level - 1
		elseif params.name == "ELEVATOR_EXIT" then
			if #warehouse.exits > 0 then
				for _, cell in ipairs(warehouse.exits) do
					if not sm.exists(warehouse.world) then
						sm.world.loadWorld(warehouse.world)
					end
					local name = params.name .. " " .. cell.x .. "," .. cell.y
					sm.portal.addWorldPortalHook(warehouse.world, name, params.portal)
					print("Added portal hook '" .. name .. "' in world " .. warehouse.world.id)

					g_elevatorManager:sv_loadBForPlayersInElevator(params.portal, warehouse.world, cell.x, cell.y)
				end
			else
				sm.log.error("No exit hint found, this elevator is going nowhere!")
			end
			return
		else
			assert(false)
		end
	else
		if params.name == "ELEVATOR_EXIT" then
			level = warehouse.maxLevels
		elseif params.name == "ELEVATOR_ENTRANCE" then
			level = 1
		else
		end
	end

	-- Create warehouse world
	local worldData = {}
	worldData.level = level
	worldData.warehouseIndex = warehouse.index
	worldData.maxLevels = warehouse.maxLevels



	local world = sm.world.createWorld("$SURVIVAL_DATA/Scripts/game/worlds/WarehouseWorld.lua", "WarehouseWorld", worldData)
	print("Created WarehouseWorld " .. world.id)

	-- Use the same restrictions for the new floor as the other floors
	warehouse.worlds[#warehouse.worlds + 1] = world
	if warehouse.restrictions then
		sm.event.sendToWorld(world, "server_updateRestrictions", warehouse.restrictions)
	end
	-- Elevator portal hook
	local name
	if params.name == "ELEVATOR_UP" then
		name = "ELEVATOR_DOWN"
	elseif params.name == "ELEVATOR_DOWN" then
		name = "ELEVATOR_UP"
	else
		name = params.name
	end
	sm.portal.addWorldPortalHook(world, name, params.portal)
	print("Added portal hook '" .. name .. "' in world " .. world.id)

	g_elevatorManager:sv_loadBForPlayersInElevator(params.portal, world, 0, 0)
end

function FactoryGame.sv_e_elevatorEvent(self, params)
	print("FactoryGame.sv_e_elevatorEvent")
	print(params)
	g_elevatorManager[params.fn](g_elevatorManager, params)
end

function FactoryGame.sv_createNewPlayer(self, world, x, y, player)
	local params = { player = player, x = x, y = y }
	sm.event.sendToWorld(self.sv.saved.overworld, "sv_spawnNewCharacter", params)
end

function FactoryGame.sv_recreatePlayerCharacter(self, world, x, y, player, params)
	local yaw = math.atan2(params.dir.y, params.dir.x) - math.pi / 2
	local pitch = math.asin(params.dir.z)
	local newCharacter = sm.character.createCharacter(player, self.sv.saved.overworld, params.pos, yaw, pitch)
	player:setCharacter(newCharacter)
	print("Recreate character in new world")
	print(params)
end

function FactoryGame.sv_e_respawn(self, params)
	if params.player.character and sm.exists(params.player.character) then
		g_respawnManager:sv_requestRespawnCharacter(params.player)
	else
		local spawnPoint = g_survivalDev and SURVIVAL_DEV_SPAWN_POINT or START_AREA_SPAWN_POINT
		if not sm.exists(self.sv.saved.overworld) then
			sm.world.loadWorld(self.sv.saved.overworld)
		end
		self.sv.saved.overworld:loadCell(math.floor(spawnPoint.x / 64), math.floor(spawnPoint.y / 64), params.player,
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

function FactoryGame.sv_e_markBag(self, params)
	if sm.exists(params.world) then
		sm.event.sendToWorld(params.world, "sv_e_markBag", params)
	else
		sm.log.warning("FactoryGame.sv_e_markBag in a world that doesn't exist")
	end
end

function FactoryGame.sv_e_unmarkBag(self, params)
	if sm.exists(params.world) then
		sm.event.sendToWorld(params.world, "sv_e_unmarkBag", params)
	else
		sm.log.warning("FactoryGame.sv_e_unmarkBag in a world that doesn't exist")
	end
end

-- Beacons
function FactoryGame.sv_e_createBeacon(self, params)
	if sm.exists(params.beacon.world) then
		sm.event.sendToWorld(params.beacon.world, "sv_e_createBeacon", params)
	else
		sm.log.warning("FactoryGame.sv_e_createBeacon in a world that doesn't exist")
	end
end

function FactoryGame.sv_e_destroyBeacon(self, params)
	if sm.exists(params.beacon.world) then
		sm.event.sendToWorld(params.beacon.world, "sv_e_destroyBeacon", params)
	else
		sm.log.warning("FactoryGame.sv_e_destroyBeacon in a world that doesn't exist")
	end
end

function FactoryGame.sv_e_unloadBeacon(self, params)
	if sm.exists(params.beacon.world) then
		sm.event.sendToWorld(params.beacon.world, "sv_e_unloadBeacon", params)
	else
		sm.log.warning("FactoryGame.sv_e_unloadBeacon in a world that doesn't exist")
	end
end



--FACTORY
function FactoryGame:sv_addMoney(money)
	MoneyManager.sv_addMoney(tonumber(money))
end

function FactoryGame:sv_setMoney(money)
	MoneyManager.sv_setMoney(tonumber(money))
end

function FactoryGame:sv_factoryRaid()
	print("CUSTOM RAID")
	local level = 1
	local wave = 1
	local hours = 12

	sm.event.sendToWorld(self.sv.saved.overworld, "sv_raid", {level = level, wave = wave, hours = hours})
end

---@param message string
function FactoryGame:cl_displayAlert(message)
	sm.gui.displayAlertText(message)
end

function FactoryGame:sv_e_showTagMessage(params)
	if params.player then
		self.network:sendToClient(params.player, "cl_onMessage", params.tag)
	else
		self.network:sendToClients("cl_onMessage", params.tag)
	end
end

function FactoryGame:cl_onMessage(tag)
	sm.gui.displayAlertText(language_tag(tag))
end


function FactoryGame:sv_e_stonks(params)
	sm.event.sendToWorld(self.sv.saved.overworld, "sv_e_stonks", params)
end



--cursed stuff to disable chunk unloading
function FactoryGame.sv_loadTerrain(self, data)
	for x = data.minX, data.maxX do
		for y = data.minY, data.maxY do
			data.world:loadCell(x, y, nil, "sv_empty")
		end
	end
end

function FactoryGame.sv_empty(self)
end