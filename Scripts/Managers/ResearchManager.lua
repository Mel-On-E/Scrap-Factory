dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PollutionManager.lua")

---@class ResearchManager : ScriptableObjectClass
ResearchManager = class()
ResearchManager.isSaveObject = true

g_tiers = sm.json.open("$CONTENT_DATA/Scripts/tiers.json")

function ResearchManager:server_onCreate()
    self.sv = {}
    self.sv.tier = 1

    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.research = {}
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end

    for tier, progress in ipairs(self.sv.saved.research) do
        if progress == g_tiers[tier].goal then
            self.sv.tier = tier + 1
        end
    end

    if not g_ResearchManager then
        g_ResearchManager = self
    end
end

function ResearchManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self:sv_saveDataAndSync()
    end

    if self.sv.notify then
        self.network:sendToClients("cl_research_done", self.sv.tier - 1)
        self.sv.notify = false
    end
end

function ResearchManager:sv_saveDataAndSync()
    self.storage:save(packNetworkData(self.sv.saved))

    local clientData = { research = self.sv.saved.research,
        tier = self.sv.tier,
        progress = self:sv_getProgress() }
    self.network:setClientData(packNetworkData(clientData))
end

function ResearchManager.sv_addResearch(value, shape)
    local tier = g_tiers[g_ResearchManager.sv.tier]
    if shape and tier.uuid ~= tostring(shape.uuid) then
        return false
    end

    local reserachProgress = g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier]
    local goal = tier.goal * PollutionManager.getResearchMultiplier()

    g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier] = math.min((reserachProgress or 0) + value, goal)

    if goal == g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier] then
        g_ResearchManager.sv.tier = g_ResearchManager.sv.tier + 1
        g_ResearchManager.sv.notify = true

        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "ResearchComplete")
    end

    return true
end

function ResearchManager:getTierProgress()
    return (self.sv and self:sv_getProgress()) or self.cl.data.progress
end

function ResearchManager:sv_getProgress()
    progressFraction = (self.sv.saved.research[self.sv.tier] or 0) /
        (g_tiers[self.sv.tier].goal * PollutionManager.getResearchMultiplier())
    return string.format("%.2f", progressFraction * 100)
end

function ResearchManager:sv_resetResearch()
    self.sv.saved.research[self.sv.tier] = 0
    self.storage:save(self.sv.saved)

    self:sv_saveDataAndSync()
end

function ResearchManager:client_onCreate()
    self.cl = {}
    self.cl.data = {}
    self.cl.data.research = {}
    self.cl.data.tier = 0
    self.cl.data.progress = ""

    if not g_ResearchManager then
        g_ResearchManager = self
    end
end

function ResearchManager:client_onClientDataUpdate(clientData)
    self.cl.data = unpackNetworkData(clientData)
end

function ResearchManager:client_onFixedUpdate()
    if g_factoryHud and self.cl.data.tier > 0 then
        g_factoryHud:setIconImage("ResearchIcon", sm.uuid.new(g_tiers[self.cl.data.tier].uuid))
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

    for _, sob in ipairs(g_sobSet.scriptableObjectList) do
        _G[sob.classname].cl_close()
    end

    player = sm.localPlayer.getPlayer()
    sm.event.sendToPlayer(player, "cl_e_createEffect",
        { id = "ResearchDone", effect = "ResearchDone", host = player:getCharacter() })
    sm.event.sendToPlayer(player, "cl_e_startEffect", "ResearchDone")
    self.cl.endEffect = sm.game.getCurrentTick() + 40 * 16
end

function ResearchManager.cl_getCurrentTier()
    if g_ResearchManager then
        return g_ResearchManager.cl.data.tier
    end
end

function ResearchManager.cl_getTierProgress(tier)
    local progress = g_ResearchManager.sv.saved.research[tier] or 0
    local goal = (g_tiers[tier] and g_tiers[tier].goal) *
        PollutionManager.getResearchMultiplier()
    return progress, goal
end

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
    return sm.uuid.new(g_tiers[tier].uuid)
end

function ResearchManager.cl_getTierCount()
    return #g_tiers
end
