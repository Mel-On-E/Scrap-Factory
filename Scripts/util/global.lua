---@type Vec3 the spawnpoint in the world for all players
SPAWN_POINT = sm.vec3.new(0, 0, 20)

---@type Shop manages the shop gui
g_cl_shop = {}

---@type GuiInterface the HUD that controls the info panel at the top
g_factoryHud = {}

---@type table<string, ShopDb> the data of the shop.json file. Contains data for every item in the mod.
g_shop = {}

---@type table<string, table> content of drops.shapeset sorted per uuids
g_drops = {}

---@type boolean when true players won't take damage or lose stats
g_godMode = false

---@type boolean whether the game is in developer mode
g_survivalDev = false

---@type boolean I assume this is bxolot stuff for eh.. weird things?
g_enableCollisionTumble = false

---@type table global `EventManager` object
g_eventManager = {}

---@type table global `UnitManager` object
g_unitManager = {}

---@type table global `BeaconManager` object
g_beaconManager = {}

---@type table global `RespawnManager` object
g_respawnManager = {}

---@type World the world.
g_world = {}

---@type table global `EffectManager` object
g_effectManager = {}

---@type Effect makes music go brrr?
g_survivalMusic = {}

---@type GuiInterface the normal surival hud. Tho we disabled food and water bars.
g_survivalHud = {}

---@class languageManager
---@field language string Current Language
---global `languageManager` object
g_languageManager = {}

---@type MoneyManager
g_moneyManager = {}

---@type PerkManager
g_perkManager = {}

---@type PollutionManager
g_pollutionManager = {}

---@type PowerManager
g_powerManager = {}

---@type TutorialManager
g_tutorialManager = {}

---@type PrestigeManager
g_prestigeManager = {}

---@type SaveDataManager
g_saveDataManager = {}

---@type number the number of drops in the world
g_oreCount = 0
