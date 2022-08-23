---@class DailyRewardManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

DailyRewardManager = class()
DailyRewardManager.isSaveObject = true

local DAY = 1000*60*60*20 --20 Hours

function DailyRewardManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.time = os.time() - DAY
        self.saved.streak = 0
        self.storage:save(self.saved)
    end

    if os.time() - self.saved.time >= DAY*2 then
        self.saved.streak = 0
        self.storage:save(self.saved)
    end

    if os.time() - self.saved.time >= DAY then
        self.network:sendToClients("cl_openGui")
        self.playEffect = true
    end

    self.rewards = sm.json.open("$CONTENT_DATA/Scripts/daily rewards.json")

    self.network:setClientData({day = self.saved.streak + 1})
end

function DailyRewardManager:sv_spawnRewards(params, player)
    for i = 1, self.rewards[self.saved.streak + 1].quantity, 1 do
        local pos = player:getCharacter():getWorldPosition()
        pos.x = pos.x + (math.random()-0.5)*10
        pos.y = pos.y + (math.random()-0.5)*10
        pos.z = pos.z + 5
        LootCrateManager.sv_spawnCrate({pos = pos, uuid = self.rewards[self.saved.streak + 1].crate, effect = "Woc - Destruct"})
    end
    self.saved.streak = math.min(self.saved.streak + 1, #self.rewards - 1)
    self.saved.time = os.time()
    self.storage:save(self.saved)
end

function DailyRewardManager:client_onCreate()
    self.cl = {}
    self.cl.day = 1
end

function DailyRewardManager:client_onFixedUpdate()
    if self.gui and self.gui:isActive() and self.playEffect and sm.localPlayer.getPlayer().character then
        local player = sm.localPlayer.getPlayer()
        sm.event.sendToPlayer(player, "cl_e_createEffect", {id = "DailyReward", effect = "Confetti", host = player:getCharacter()})
        sm.event.sendToPlayer(player, "cl_e_startEffect", "DailyReward")
        self.playEffect = false
    end
    
end

function DailyRewardManager:client_onClientDataUpdate(data)
    self.cl.day = data.day
    self.cl.currentDay = data.day
end

function DailyRewardManager:cl_openGui()
    if not sm.isHost then
        return
    end

    if not self.claimed then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/DailyReward.layout")
        self.gui:setOnCloseCallback("cl_openGui")
        self.gui:setButtonCallback("Claim Reward", "cl_claimReward")
        self.gui:setButtonCallback("DayUp", "cl_dayUp")
        self.gui:setButtonCallback("DayDown", "cl_dayDown")

        self.gui:setText("title", language_tag("DailyRewardTitle"))
        self.gui:setText("ClaimRewardText", language_tag("ClaimDailyReward"))

        generateDays(self)
        self.gui:open()
    end
end

function generateDays(self)
    local offset = math.min(self.cl.day - 1, #self.rewards - 5)
    for i = 1, 5, 1 do
        local rewardDay = self.cl.currentDay == i + offset
        local color = rewardDay and "#dddd00" or "#aaaaaa"

        self.gui:setButtonState("Reward_" .. tostring(i), rewardDay)

        self.gui:setText("RewardText_" .. tostring(i), color .. language_tag("DailyRewardDay"):format(tostring(i + offset)))
        local uuid = sm.uuid.new(self.rewards[i + offset].crate)
        self.gui:setIconImage("RewardPic_" .. tostring(i), uuid)
        self.gui:setText("RewardCount_" .. tostring(i), tostring(self.rewards[i + offset].quantity))
    end
end

function DailyRewardManager:cl_dayUp()
    self.cl.day = math.min(self.cl.day + 1, #self.rewards)
    generateDays(self)
end

function DailyRewardManager:cl_dayDown()
    self.cl.day = math.max(self.cl.day - 1, 1)
    generateDays(self)
end

function DailyRewardManager:cl_claimReward()
    self.gui:close()
    self.gui:destroy()
    self.gui = nil
    self.claimed = true
    self.network:sendToServer("sv_spawnRewards")
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_destroyEffect", "DailyReward")
end

