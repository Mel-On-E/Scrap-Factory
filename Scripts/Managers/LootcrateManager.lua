dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class LootCrateManager : ScriptableObjectClass
LootCrateManager = class()

local dropInterval = 40 * 30 --ticks
local lootTable = {
    { chance = 95, uuid = obj_lootcrate },
    { chance = 5, uuid = obj_lootcrate_rare }
}

function LootCrateManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % dropInterval == 0 and g_world then
        local pos = sm.vec3.new(math.random(-(15 * 64), 15 * 64), math.random(-(15 * 64), 15 * 64), 100)
        self.sv_spawnCrate({ pos = pos, uuid = self:sv_pickCrate() })
    end
end

function LootCrateManager.sv_spawnCrate(params)
    sm.event.sendToWorld(g_world, "sv_e_createShape", params)
    if params.effect then
        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", params)
    end
end

function LootCrateManager:sv_pickCrate()
    local sum = 0
    for _, crate in pairs(lootTable) do
        sum = sum + crate.chance
    end

    local random = sum * math.random()
    for _, crate in pairs(lootTable) do
        random = random - crate.chance
        if random <= 0 then
            return crate.uuid
        end
    end
end
