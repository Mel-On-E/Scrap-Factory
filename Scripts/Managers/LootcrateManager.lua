---@class LootCrateManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

LootCrateManager = class()

local crates = {}
crates["69b869f1-03dc-4ea3-9291-fd6490f945dd"] = "normal_crate.blueprint"
crates["cf48ca1b-3d7a-4b56-83e9-092e681525be"] = "rare_crate.blueprint"

function LootCrateManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % (40 * 30) == 0 and g_world then
		local pos = sm.vec3.new(math.random(-(15 * 64), 15 * 64), math.random(-(15 * 64), 15 * 64), 100)
		self.sv_spawnCrate(pos, "69b869f1-03dc-4ea3-9291-fd6490f945dd")
	end
end

function LootCrateManager.sv_setWorld(world)
    g_world = world
end

function LootCrateManager.sv_spawnCrate(pos, uuid)
    sm.creation.importFromFile(g_world, "$CONTENT_DATA/LocalBlueprints/" .. crates[uuid], pos)
end