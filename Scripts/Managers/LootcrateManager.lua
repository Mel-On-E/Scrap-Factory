---The LootCrateManager spawns lootcrates. Randomly or manually.
---@class LootCrateManager : ScriptableObjectClass
LootCrateManager = class()

--------------------
-- #region Server
--------------------

local dropInterval = 30 *40 --30 secs
local lootTable = {
    { chance = 95, uuid = obj_lootcrate },
    { chance = 5,  uuid = obj_lootcrate_rare }
}

function LootCrateManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % dropInterval == 0 and g_world then
        local pos = sm.vec3.new(math.random(-(15 * 64), 15 * 64), math.random(-(15 * 64), 15 * 64), 100)
        self.sv_spawnCrate({ pos = pos, uuid = self:sv_pickRandomCrate() })
    end
end

---@class SpawnCrateParams : ShapeCreationParams
---@field effect string|nil name of effect to be played on spawn
---Spawn a lootCrate
---@param params SpawnCrateParams
function LootCrateManager.sv_spawnCrate(params)
    sm.event.sendToWorld(g_world, "sv_e_createShape", params)
    if params.effect then
        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", params)
    end
end

---picks a random crate uuid from the lootTable
---@return Uuid crateUuid uuid of the crate
function LootCrateManager:sv_pickRandomCrate()
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
        ---@diagnostic disable-next-line: missing-return
    end
end

-- #endregion