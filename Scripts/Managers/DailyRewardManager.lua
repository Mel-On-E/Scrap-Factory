---@class DailyRewardManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

DailyRewardManager = class()
DailyRewardManager.isSaveObject = true

local DAY = 1--1000*60*60*20 --20 Hours

function DailyRewardManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.time = os.time()
        self.saved.streak = 0
        self.storage:save(self.saved)
    end

    if os.time() - self.saved.time > DAY*2 then
        self.saved.streak = 0
        self.storage:save(self.saved)
    end

    if os.time() - self.saved.time > DAY then
        self.network:sendToClients("cl_openGui")
    end
end

function DailyRewardManager:sv_spawnRewards(params, player)
    local pos = player:getCharacter():getWorldPosition()
    pos.x = pos.x + (math.random()-0.5)*10
    pos.y = pos.y + (math.random()-0.5)*10
    pos.z = pos.z + 5
    LootCrateManager.sv_spawnCrate(pos)
end

function DailyRewardManager:cl_openGui()
    if not sm.isHost then
        return
    end

    if not self.claimed then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/DailyReward.layout")
        self.gui:setOnCloseCallback("cl_openGui")
        self.gui:setButtonCallback("Claim Reward", "cl_claimReward")

        self.gui:setText("title", language_tag("DailyRewardTitle"))
        self.gui:setText("ClaimRewardText", language_tag("ClaimDailyReward"))

        self.gui:open()
    end
end

function DailyRewardManager:cl_claimReward()
    self.gui:close()
    self.claimed = true
    self.network:sendToServer("sv_spawnRewards")
end