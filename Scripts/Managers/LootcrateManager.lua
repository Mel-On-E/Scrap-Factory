---@class LootCrateManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

LootCrateManager = class()

function LootCrateManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % (40 * 30) == 0 and g_world then
		local pos = sm.vec3.new(math.random(-(15 * 64), 15 * 64), math.random(-(15 * 64), 15 * 64), 100)
		self.sv_spawnCrate(pos)
	end
end

function LootCrateManager.sv_setWorld(world)
    g_world = world
end

function LootCrateManager.sv_spawnCrate(pos)
    sm.creation.importFromFile(g_world, "$CONTENT_DATA/LocalBlueprints/crate.blueprint", pos)
end