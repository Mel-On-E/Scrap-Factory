---Manages the research progress, keeps track of the research tiers etc.
---@class ResearchManager : ScriptableObjectClass
---@field sv ResearchManagerSv
---@field cl ResearchManagerCl
ResearchManager = class()
ResearchManager.isSaveObject = true

---@type TierData[] tier data from tiers.json
tiersJson = sm.json.open("$CONTENT_DATA/Scripts/tiers.json")
for k, v in ipairs(tiersJson) do
    v.uuid = sm.uuid.new(v.uuid)
    ---@diagnostic disable-next-line: assign-type-mismatch
    v.goal = tonumber(v.goal)
end

--------------------
-- #region Server
--------------------

function ResearchManager:server_onCreate()
    g_ResearchManager = g_ResearchManager or self

    self.sv = {}
    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.tier = 1
        self.sv.saved.research = {}
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end
end

function ResearchManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self:sv_saveDataAndSync()
    end
end

function ResearchManager:sv_saveDataAndSync()
    self.storage:save(packNetworkData(self.sv.saved))

    local clientData = {
        research = self.sv.saved.research,
        tier = self.sv.saved.tier,
        progress = self:sv_getProgressString()
    }
    self.network:setClientData(packNetworkData(clientData))
end

---Add research points towards the current research goal
---@param value number amount of research points to be added
---@param shape Shape|nil will only add research points if the shape is the current research shape
---@return boolean success whether research points have been added
function ResearchManager.sv_addResearch(value, shape)
    local tier = g_ResearchManager.sv.saved.tier
    local tierData = tiersJson[tier]
    if shape and tierData.uuid ~= shape.uuid then
        return false
    end

    local reserachProgress = g_ResearchManager.sv.saved.research[tier]
    local goal = tierData.goal * PollutionManager.getResearchMultiplier()

    g_ResearchManager.sv.saved.research[tier] = math.min((reserachProgress or 0) + value, goal)

    if goal == g_ResearchManager.sv.saved.research[tier] then
        sm.event.sendToScriptableObject(g_ResearchManager.scriptableObject, "sv_researchDone")
    end

    return true
end

function ResearchManager:sv_researchDone()
    self.sv.saved.tier = self.sv.saved.tier + 1
    self:sv_saveDataAndSync()

    self.network:sendToClients("cl_research_done", self.sv.saved.tier - 1)

    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "ResearchComplete")
end

function ResearchManager.sv_setTier(self, value)
    local tier = g_tiers[value]
    if tier then
        print("Tier set " .. value)
        g_ResearchManager.sv.saved.tier = value + 1
        g_ResearchManager.sv.notify = true
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "ResearchComplete")
        sm.event.sendToScriptableObject(g_ResearchManager.scriptableObject, "sv_saveDataAndSync")
    end
end
function ResearchManager:sv_addResearchManual(value)
    local tier = g_tiers[g_ResearchManager.sv.saved.tier]
    g_ResearchManager.sv.saved.research = math.min(value, tier.goal)
end

---get tier progress as a formatted string
---@return string progress the current tier progress formatted as a % value
function ResearchManager:sv_getProgressString()
    progressFraction = (self.sv.saved.research[self.sv.saved.tier] or 0) /
        (tiersJson[self.sv.saved.tier].goal * PollutionManager.getResearchMultiplier())
    return string.format("%.2f", progressFraction * 100)
end

---reset the current research progress (in case of prestige)
function ResearchManager:sv_resetResearchProgress()
    self.sv.saved.research[self.sv.saved.tier] = 0
    self.storage:save(self.sv.saved)

    self:sv_saveDataAndSync()
end

-- #endregion

function ResearchManager:getTierProgress()
    return (self.sv and self:sv_getProgressString()) or self.cl.data.progress
end

--------------------
-- #region Client
--------------------

function ResearchManager:client_onCreate()
    g_ResearchManager = g_ResearchManager or self

    self.cl = {
        data = {
            research = {},
            tier = 0,
            progress = "",
        }
    }
end

function ResearchManager:client_onClientDataUpdate(clientData)
    self.cl.data = unpackNetworkData(clientData)
end

function ResearchManager:client_onFixedUpdate()
    if g_factoryHud and self.cl.data.tier > 0 then
        g_factoryHud:setIconImage("ResearchIcon", tiersJson[self.cl.data.tier].uuid)
        g_factoryHud:setText("Research", "#00dddd" .. self:getTierProgress() .. "%")
    end

    if self.cl.endEffect and self.cl.endEffect < sm.game.getCurrentTick() then
        self.cl.endEffect = nil
        sm.event.sendToPlayer(player, "cl_e_destroyEffect", "ResearchDone")
    end
end

function ResearchManager:cl_research_done(tier)
    sm.gui.displayAlertText("#00dddd" .. string.format(language_tag("ResearchFinished"), tostring(tier)))

    local unlocks = self.cl_getTierUnlocks(tier)
    for _, uuid in ipairs(unlocks) do
        sm.gui.chatMessage(language_tag("RsearchUnlockItem") .. "#00dddd" .. sm.shape.getShapeTitle(sm.uuid.new(uuid)))
    end

    Interface.cl_closeAllInterfaces()

    player = sm.localPlayer.getPlayer()
    sm.event.sendToPlayer(player, "cl_e_createEffect",
        { key = "ResearchDone", effect = "ResearchDone", host = player:getCharacter() })
    self.cl.endEffect = sm.game.getCurrentTick() + 40 * 16
end

function ResearchManager.cl_getCurrentTier()
    return g_ResearchManager and g_ResearchManager.cl.data.tier
end

---Get info about a research tier
---@param tier integer the tier of which to get its info
---@return number progress amount of research points earned so far
---@return number goal amount of research ponts needed for completition
function ResearchManager.cl_getTierProgressInfo(tier)
    local progress = g_ResearchManager.sv.saved.research[tier] or 0
    local goal = (tiersJson[tier] and tiersJson[tier].goal) *
        PollutionManager.getResearchMultiplier()
    return progress, goal
end

---get a list of items to be unlocked
---@param tier integer tier of which to get the unlocks
---@return table<integer, Uuid> unlocks list of items to be unlocked
function ResearchManager.cl_getTierUnlocks(tier)
    local unlocks = {}
    for uuid, item in pairs(g_shop) do
        if item.tier == tier then
            unlocks[#unlocks + 1] = uuid
        end
    end

    return unlocks
end

function ResearchManager.cl_getTierUuid(tier)
    return tiersJson[tier].uuid
end

function ResearchManager.cl_getTierCount()
    return #tiersJson
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class TierData
---@field uuid Uuid uuid of the research shape that needs to be sold to gain research points
---@field goal integer base value of research points needed to complete this tier

---@class ResearchManagerSv
---@field saved ResearchManagerSvSaved
---@field notify boolean

---@class ResearchManagerSvSaved
---@field tier integer currently saved research tier
---@field research table<integer, number> `<tier, research points>`

---@class ResearchManagerCl
---@field data ResearchManagerClData clientData

---@class ResearchManagerClData
---@field progress string current tier progress formatted
---@field tier integer current research tier
---@field research table<integer, number> `<tier, research points>`

-- #endregion
