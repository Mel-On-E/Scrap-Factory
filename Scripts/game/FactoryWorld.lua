dofile("$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_spawns.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$GAME_DATA/Scripts/game/managers/EventManager.lua")

---The world in which a player, creations, and such exists
---@class FactoryWorld : WorldClass
---@field pesticideManager table
---@field ambienceEffect table
---@field birdAmbience table
---@field birdAmbienceTimer table
FactoryWorld = class()

FactoryWorld.terrainScript = "$GAME_DATA/Scripts/terrain/terrain_creative.lua"
FactoryWorld.groundMaterialSet = "$GAME_DATA/Terrain/Materials/gnd_standard_materialset.json"
FactoryWorld.isStatic = true -- this disables chunk loading
FactoryWorld.enableSurface = true
FactoryWorld.enableAssets = true
FactoryWorld.enableClutter = false
FactoryWorld.enableNodes = false
FactoryWorld.enableCreations = true
FactoryWorld.enableHarvestables = false
FactoryWorld.enableKinematics = false
FactoryWorld.renderMode = "outdoor"
FactoryWorld.cellMinX = -15
FactoryWorld.cellMaxX = 14
FactoryWorld.cellMinY = -15
FactoryWorld.cellMaxY = 14

--------------------
-- #region Server
--------------------

function FactoryWorld.server_onCreate(self)
	self.pesticideManager = PesticideManager()
	self.pesticideManager:sv_onCreate()

	local data = {
		minX = self.cellMinX or 0,
		maxX = self.cellMaxX or 0,
		minY = self.cellMinY or 0,
		maxY = self.cellMaxY or 0,
		world = self.world
	}
	sm.event.sendToGame("sv_loadTerrain", data)
end

function FactoryWorld.server_onFixedUpdate(self)
	self.pesticideManager:sv_onWorldFixedUpdate(self)

	g_unitManager:sv_onWorldFixedUpdate(self)
end

---Spanws a new character in the world. Only called the first time a char is created.
---@param params table `x, y` - spawn position; `player` - the player the char belongs to
function FactoryWorld.sv_spawnNewCharacter(self, params)
	local spawnRayBegin = sm.vec3.new(params.x, params.y, 1024)
	local spawnRayEnd = sm.vec3.new(params.x, params.y, -1024)
	local valid, result = sm.physics.spherecast(spawnRayBegin, spawnRayEnd, 0.3)
	local pos
	if valid then
		pos = result.pointWorld + sm.vec3.new(0, 0, 0.4)
	else
		pos = sm.vec3.new(params.x, params.y, 100)
	end

	local character = sm.character.createCharacter(params.player, self.world, pos)
	params.player:setCharacter(character)
	sm.event.sendToGame("sv_e_setSpawnPoint", pos)
end

function FactoryWorld.sv_e_onChatCommand(self, params)
	if params[1] == "/aggroall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs(units) do
			sm.event.sendToUnit(unit, "sv_e_receiveTarget", { targetCharacter = params.player.character })
		end
		sm.gui.chatMessage("Units in overworld are aware of PLAYER" .. tostring(params.player.id) .. " position.")
	elseif params[1] == "/killall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs(units) do
			unit:destroy()
		end
	end
end

function FactoryWorld.server_onProjectile(self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal,
										  target, projectileUuid)
	-- Spawn loot from projectiles with loot user data
	if userData and userData.lootUid then
		local normal = -hitVelocity:normalize()
		local zSignOffset = math.min(sign(normal.z), 0) * 0.5
		local offset = sm.vec3.new(0, 0, zSignOffset)
		local lootHarvestable = sm.harvestable.createHarvestable(hvs_loot, hitPos + offset,
			sm.vec3.getRotation(sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1)))
		---@diagnostic disable-next-line: need-check-nil
		lootHarvestable:setParams({ uuid = userData.lootUid, quantity = userData.lootQuantity, epic = userData.epic })
	end

	-- Notify units about projectile hit
	if isAnyOf(projectileUuid, g_potatoProjectiles) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs(units) do
			sm.event.sendToUnit(unit, "sv_e_worldEvent",
				{
					eventName = "projectileHit",
					hitPos = hitPos,
					hitTime = hitTime,
					hitVelocity = hitVelocity,
					attacker = attacker,
					damage = damage
				})
		end
	end

	-- Manage projectile effects
	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new(0, 1, 0)
		local randomDir = forward:rotateZ(math.random(0, 359))
		local effectPos = hitPos
		local success, result = sm.physics.raycast(hitPos + sm.vec3.new(0, 0, 0.1),
			hitPos - sm.vec3.new(0, 0, PESTICIDE_SIZE.z * 0.5), nil,
			sm.physics.filter.static + sm.physics.filter.dynamicBody)
		if success then
			effectPos = result.pointWorld + sm.vec3.new(0, 0, PESTICIDE_SIZE.z * 0.5)
		end
		self.pesticideManager:sv_addPesticide(self, effectPos, sm.vec3.getRotation(forward, randomDir))
	elseif projectileUuid == projectile_glowstick then
		sm.harvestable.createHarvestable(hvs_remains_glowstick, hitPos,
			sm.vec3.getRotation(sm.vec3.new(0, 1, 0), hitVelocity:normalize()))
	elseif projectileUuid == projectile_explosivetape then
		sm.physics.explode(hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit")
	end
end

function FactoryWorld.server_onMelee(self, hitPos, attacker, target, damage, power, hitDirection, hitNormal)
	if attacker and sm.exists(attacker) and target and sm.exists(target) then
		if type(target) == "Shape" and type(attacker) == "Unit" then
			local targetPlayer = nil
			if target.interactable and target.interactable:hasSeat() then
				local targetCharacter = target.interactable:getSeatCharacter()
				if targetCharacter then
					targetPlayer = targetCharacter:getPlayer()
				end
			end
			if targetPlayer then
				sm.event.sendToPlayer(targetPlayer, "sv_e_receiveDamage", { damage = damage })
			end
		end
	end
end

function FactoryWorld.server_onCollision(self, objectA, objectB, collisionPosition, objectAPointVelocity,
										 objectBPointVelocity, collisionNormal)
	g_unitManager:sv_onWorldCollision(self, objectA, objectB, collisionPosition, objectAPointVelocity,
		objectBPointVelocity
		, collisionNormal)
end

function FactoryWorld.sv_e_spawnUnit(self, params)
	for i = 1, params.amount do
		sm.unit.createUnit(params.uuid, params.position, params.yaw)
	end
end

function FactoryWorld.sv_spawnHarvestable(self, params)
	local harvestable = sm.harvestable.createHarvestable(params.uuid, params.position, params.quat)
	if params.harvestableParams then
		---@diagnostic disable-next-line: need-check-nil
		harvestable:setParams(params.harvestableParams)
	end
end

function FactoryWorld.sv_e_spawnTempUnitsOnCell(self, params)
	local cellSize = 64.0
	local cellSteps = cellSize - 1
	local xCoordMin = params.x * cellSize + (params.x < 0 and (cellSteps) or 0)
	local yCoordMin = params.y * cellSize + (params.y < 0 and (cellSteps) or 0)
	local xCoordMax = xCoordMin + (params.x < 0 and cellSteps * -1 or cellSteps)
	local yCoordMax = yCoordMin + (params.y < 0 and cellSteps * -1 or cellSteps)

	local unitCount = 0
	local spawnMagnitude = math.random(0, 99)
	if spawnMagnitude > 98 then  -- ( 99 - 1 )
		unitCount = 3
	elseif spawnMagnitude > 93 then -- ( 99 - 1 - 5 )
		unitCount = 2
	elseif spawnMagnitude > 83 then -- ( 99 - 1 - 5 - 10 )
		unitCount = 1
	end
	if unitCount == 0 then
		return
	end

	local cellPosition = sm.vec3.new((xCoordMin + xCoordMax) * 0.5, (yCoordMin + yCoordMax) * 0.5, 0.0)
	local minDistance = 0.0
	local maxDistance = cellSize * 0.5
	local validNodes = sm.pathfinder.getSortedNodes(cellPosition, minDistance, maxDistance)
	---@diagnostic disable-next-line: deprecated
	local validNodesCount = table.maxn(validNodes)

	local incomingUnits = g_unitManager:sv_getRandomUnits(unitCount, nil)

	if validNodesCount > 0 then
		--print( unitCount .. " enemies are approaching!" )
		for i = 1, #incomingUnits do
			local selectedNode = math.random(validNodesCount)
			local unitPos = validNodes[selectedNode]:getPosition()

			if validNodesCount >= #incomingUnits - i then
				table.remove(validNodes, selectedNode)
				validNodesCount = validNodesCount - 1
			end

			sm.unit.createUnit(incomingUnits[i], unitPos + sm.vec3.new(0, 0.1, 0), 0, { temporary = true })
		end
	else
		local maxSpawnAttempts = 32
		for i = 1, #incomingUnits do
			local spawnAttempts = 0
			while spawnAttempts < maxSpawnAttempts do
				spawnAttempts = spawnAttempts + 1
				local subdivisions = sm.construction.constants.subdivisions
				local subdivideRatio = sm.construction.constants.subdivideRatio
				local spawnPosition = sm.vec3.new(
					math.random(xCoordMin * subdivisions, xCoordMax * subdivisions) * subdivideRatio,
					math.random(yCoordMin * subdivisions, yCoordMax * subdivisions) * subdivideRatio,
					0.0)

				local success, result = sm.physics.raycast(spawnPosition + sm.vec3.new(0, 0, 128),
					spawnPosition + sm.vec3.new(0, 0, -128), nil, sm.physics.filter.all)
				if success and (result.type == "limiter" or result.type == "terrainSurface") then
					local direction = sm.vec3.new(0, 1, 0)
					---@diagnostic disable-next-line: deprecated
					local yaw = math.atan2(direction.y, direction.x) - math.pi / 2
					spawnPosition = result.pointWorld
					sm.unit.createUnit(incomingUnits[i], spawnPosition, yaw, { temporary = true })
					break
				end
			end
		end
	end
end

function FactoryWorld.server_onInteractableCreated(self, interactable)
	g_unitManager:sv_onInteractableCreated(interactable)
end

function FactoryWorld.server_onInteractableDestroyed(self, interactable)
	g_unitManager:sv_onInteractableDestroyed(interactable)
end

function FactoryWorld.server_onCellCreated(self, x, y)
	g_unitManager:sv_onWorldCellLoaded(self, x, y)
end

function FactoryWorld.server_onCellLoaded(self, x, y)
	g_unitManager:sv_onWorldCellReloaded(self, x, y)
end

---create a new shape in the world
---@param params ShapeCreationParams
function FactoryWorld:sv_e_createShape(params)
	local shape = sm.shape.createPart(params.uuid, params.pos, params.rot or sm.quat.identity())
	if params.publicData then
		shape.interactable:setPublicData(unpackNetworkData(params.publicData))
	end
end

-- #endregion

--------------------
-- #region Client
--------------------

function FactoryWorld.client_onCreate(self)
	if self.pesticideManager == nil then
		assert(not sm.isHost)
		self.pesticideManager = PesticideManager()
	end
	self.pesticideManager:cl_onCreate()

	self.ambienceEffect = sm.effect.createEffect("OutdoorAmbience")
	self.ambienceEffect:start()
	self.birdAmbienceTimer = Timer()
	self.birdAmbienceTimer:start(40)
	self.birdAmbience = { near = {}, far = {} }
end

function FactoryWorld.client_onDestroy(self)
	if sm.exists(self.ambienceEffect) then
		self.ambienceEffect:destroy()
		self.ambienceEffect = nil
	end
	if sm.exists(self.birdAmbience.near.effect) then
		self.birdAmbience.near.effect:destroy()
		self.birdAmbience.near.effect = nil
	end
	self.birdAmbience.near = {}
	if sm.exists(self.birdAmbience.far.effect) then
		self.birdAmbience.far.effect:destroy()
		self.birdAmbience.far.effect = nil
	end
	self.birdAmbience.far = {}
end

function FactoryWorld.client_onFixedUpdate(self)
	-- Update ambient birds
	self.birdAmbienceTimer:tick()
	if self.birdAmbienceTimer:done() then
		self.birdAmbienceTimer:reset()
		local myCharacter = sm.localPlayer.getPlayer().character
		if sm.exists(myCharacter) then
			local nearbyTree = sm.ai.getClosestTree(myCharacter.worldPosition, self.world)
			if sm.exists(nearbyTree) then
				if self.birdAmbience.near.harvestable ~= nearbyTree then
					if nearbyTree.clientPublicData and nearbyTree.clientPublicData.crownPosition then
						-- Remove far bird
						if sm.exists(self.birdAmbience.far.effect) then
							self.birdAmbience.far.effect:destroy()
						end
						self.birdAmbience.far = {}

						-- Move previous near bird to far
						self.birdAmbience.far.effect = self.birdAmbience.near.effect
						self.birdAmbience.far.harvestable = self.birdAmbience.near.harvestable

						-- Setup new near bird
						self.birdAmbience.near.harvestable = nearbyTree
						self.birdAmbience.near.effect = sm.effect.createEffect("Tree - Ambient Birds")
						self.birdAmbience.near.effect:setPosition(nearbyTree.clientPublicData.crownPosition)
						self.birdAmbience.near.effect:start()
					end
				end
			end
		end
	end
end

function FactoryWorld.client_onUpdate(self, deltaTime)
	g_effectManager:cl_onWorldUpdate(self)

	g_unitManager:cl_onWorldUpdate(self, deltaTime)

	local night = 1.0 - getDayCycleFraction()
	self.ambienceEffect:setParameter("amb_day_night", night)

	local character = sm.localPlayer.getPlayer():getCharacter()
	if character and character:getWorld() == self.world then
		if not g_survivalMusic:isPlaying() then
			g_survivalMusic:start()
		end

		local time = sm.game.getTimeOfDay()

		if time > 0.21 and time < 0.5 then -- dawn
			g_survivalMusic:setParameter("music", 2)
		elseif time > 0.5 and time < 0.875 then -- daynoon
			g_survivalMusic:setParameter("music", 3)
		else                              -- night
			g_survivalMusic:setParameter("music", 4)
		end
	end
end

function FactoryWorld.cl_n_unitMsg(self, msg)
	g_unitManager[msg.fn](g_unitManager, msg)
end

-- #endregion

--------------------
-- #region Beacons
--------------------

function FactoryWorld.sv_e_createBeacon(self, params)
	if params.player and sm.exists(params.player) then
		self.network:sendToClient(params.player, "cl_n_createBeacon", params)
	else
		self.network:sendToClients("cl_n_createBeacon", params)
	end
end

function FactoryWorld.cl_n_createBeacon(self, params)
	g_beaconManager:cl_createBeacon(params)
end

function FactoryWorld.sv_e_destroyBeacon(self, params)
	if params.player and sm.exists(params.player) then
		self.network:sendToClient(params.player, "cl_n_destroyBeacon", params)
	else
		self.network:sendToClients("cl_n_destroyBeacon", params)
	end
end

function FactoryWorld.cl_n_destroyBeacon(self, params)
	g_beaconManager:cl_destroyBeacon(params)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ShapeCreationParams
---@field uuid Uuid uuid of the shape to be created
---@field pos Vec3 worldPosition where the shape will be created
---@field rot Quat (optional) worldRotation of the shape
---@field publicData table (optional) publicData to be set on the newly created shape

-- #endregion
