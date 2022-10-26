dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class LootCrateManager : ScriptableObjectClass
LootCrateManager = class()

function LootCrateManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % (40 * 30) == 0 and g_world then
        local pos = sm.vec3.new(math.random(-(15 * 64), 15 * 64), math.random(-(15 * 64), 15 * 64), 100)
        self.sv_spawnCrate({ pos = pos, uuid = sm.uuid.new("69b869f1-03dc-4ea3-9291-fd6490f945dd") })
    end
end

function LootCrateManager.sv_spawnCrate(params)
    sm.event.sendToWorld(g_world, "sv_e_createShape", params)
    if params.effect then
        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", params)
    end
end
