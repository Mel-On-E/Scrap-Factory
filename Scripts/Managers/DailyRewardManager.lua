---Manages the daily rewards
---@class DailyRewardManager : ScriptableObjectClass
---@field sv DailyRewardManagerSv
---@field cl DailyRewardManagerCl
DailyRewardManager = class()
DailyRewardManager.isSaveObject = true

---daily rewards.json
local RewardTable = sm.json.open("$CONTENT_DATA/Scripts/daily rewards.json")

--------------------
-- #region Server
--------------------

---The minimum amoutn of time passed to claim another daily reward:
local MinRewardInterval = 60 * 60 * 20 --20 Hours
---Maximum amount of time to keep up the reward streak
local MaxStreakTime = MinRewardInterval * 2

function DailyRewardManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load() or {
        time = os.time() - MinRewardInterval,
        streak = 0
    }
    self.storage:save(self.sv.saved)

    --check if streak still valid
    if os.time() - self.sv.saved.time >= MaxStreakTime then
        self.sv.saved.streak = 0
    end

    --check for daily reward
    if os.time() - self.sv.saved.time >= MinRewardInterval then
        self.network:sendToClients("cl_openGui")
    end

    self.network:setClientData({ day = self.sv.saved.streak + 1 })
end

---spawns the current daily reward aroudn the player and saves streak
function DailyRewardManager:sv_spawnRewards(_, player)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "DailyRewardClaimed")

    for i = 1, RewardTable[self.sv.saved.streak + 1].quantity, 1 do
        local pos = player:getCharacter():getWorldPosition()
        pos.x = pos.x + (math.random() - 0.5) * 10
        pos.y = pos.y + (math.random() - 0.5) * 10
        pos.z = pos.z + 5

        LootCrateManager.sv_spawnCrate({
            pos = pos,
            uuid = sm.uuid.new(RewardTable[self.sv.saved.streak + 1].crate),
            effect = "Woc - Destruct"
        })
    end

    self.sv.saved.streak = math.min(self.sv.saved.streak + 1, #RewardTable - 1)
    self.sv.saved.time = os.time()
    self.storage:save(self.sv.saved)
end

-- #endregion

--------------------
-- #region Client
--------------------

function DailyRewardManager:client_onCreate()
    self.cl = {
        day = 1,
        claimed = false
    }
end

function DailyRewardManager:client_onFixedUpdate()
    if not self.cl.claimed and self.cl.gui and not self.cl.gui:isActive() then
        self.cl.gui:open()
    end

    local player = sm.localPlayer.getPlayer()
    if player:getCharacter() and self.cl.gui and self.cl.gui:isActive() and self.cl.playEffect then
        sm.event.sendToPlayer(player, "cl_e_createEffect", {
            key = "DailyReward",
            effect = "Confetti",
            host = player:getCharacter()
        })
        self.cl.playEffect = nil
    end
end

function DailyRewardManager:client_onClientDataUpdate(data)
    self.cl.guiDayIndex = data.day
    self.cl.currentRewardDay = data.day
end

function DailyRewardManager:cl_openGui()
    if not sm.isHost then
        return
    end

    if not self.cl.claimed then
        self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/DailyReward.layout")
        self.cl.gui:setOnCloseCallback("cl_openGui")
        self.cl.gui:setButtonCallback("Claim Reward", "cl_claimReward")
        self.cl.gui:setButtonCallback("DayUp", "cl_dayIndexUp")
        self.cl.gui:setButtonCallback("DayDown", "cl_dayIndexDown")

        self.cl.gui:setText("title", language_tag("DailyRewardTitle"))
        self.cl.gui:setText("ClaimRewardText", language_tag("ClaimDailyReward"))

        self:cl_updateDisplayedRewards()
        self.cl.gui:open()
        self.cl.playEffect = true
    end
end

---update the daily rewards shown in the gui
function DailyRewardManager:cl_updateDisplayedRewards()
    local dayOffset = math.min(self.cl.guiDayIndex - 1, #RewardTable - 5)

    for i = 1, 5 do
        local rewardDay = self.cl.currentRewardDay == i + dayOffset
        local color = rewardDay and "#dddd00" or "#aaaaaa"

        self.cl.gui:setButtonState("Reward_" .. tostring(i), rewardDay)

        self.cl.gui:setText("RewardText_" .. tostring(i),
            color .. language_tag("DailyRewardDay"):format(tostring(i + dayOffset)))
        local uuid = sm.uuid.new(RewardTable[i + dayOffset].crate)
        self.cl.gui:setIconImage("RewardPic_" .. tostring(i), uuid)
        self.cl.gui:setText("RewardCount_" .. tostring(i), tostring(RewardTable[i + dayOffset].quantity))
    end
end

function DailyRewardManager:cl_dayIndexUp()
    self.cl.guiDayIndex = math.min(self.cl.guiDayIndex + 1, #RewardTable)
    self:cl_updateDisplayedRewards()
end

function DailyRewardManager:cl_dayIndexDown()
    self.cl.guiDayIndex = math.max(self.cl.guiDayIndex - 1, 1)
    self:cl_updateDisplayedRewards()
end

function DailyRewardManager:cl_claimReward()
    self.cl.gui:close()
    self.cl.gui:destroy()
    self.cl.gui = nil
    self.cl.claimed = true
    self.network:sendToServer("sv_spawnRewards")
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_destroyEffect", "DailyReward")
end

--------------------
-- #region Server
--------------------

---@class DailyRewardManagerSv
---@field saved DailyRewardManagerSvSaved

---@class DailyRewardManagerSvSaved
---@field time number when the last reward was claimed
---@field streak number the reward streak so far

---@class DailyRewardManagerCl
---@field guiDayIndex number the index of the day "selected" in the gui
---@field currentRewardDay number the day of the current daily reward
---@field gui GuiInterface daily reward gui
---@field playEffect boolean wether the daily reward effects should be started
---@field claimed boolean whether the daily reward has been claimed

-- #endregion
