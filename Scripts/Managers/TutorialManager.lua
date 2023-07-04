---Manages pop up tutorials, the quest trackerHud, and progress of tutorials.
---@class TutorialManager : ScriptableObjectClass
---@field sv TutorialManagerSv
---@field cl TutorialManagerCl
TutorialManager = class()
TutorialManager.isSaveObject = true

---@type Tutorial[] ---Specifies the order and events of the tutorials
local tutorialSteps = {
    {
        events = {
            "DailyRewardClaimed"
        },
        tutorial = "WelcomeTutorial"
    },
    {
        events = {
            "DropperPlaced",
            "FurnacePlaced"
        },
        tutorial = "PowerTutorial"
    },
    {
        events = {
            "WindmillPlaced"
        },
        tutorial = "WindmillTutorial"
    },
    {
        events = {
            "WindmillTutorialWatched"
        },
        tutorial = "DropperTutorial"
    },
    {
        events = {
            "MoneyMade"
        },
        tutorial = "ShopTutorial"
    },
    {
        events = {
            "100Money",
            "UpgraderBought"
        },
        tutorial = "UpgraderTutorial"
    },
    {
        events = {
            "SellUpgradedDrop",
        },
        tutorial = "ResearchFurnaceTutorial"
    },
    {
        events = {
            "ResearchFurnaceSet",
        },
        tutorial = "ResearchTutorial"
    },
    {
        events = {
            "ResearchComplete",
        },
        tutorial = "GetRichTutorial"
    },
    {
        events = {
            "1BMoney",
        },
        tutorial = "PrestigeTutorial"
    }

}

--------------------
-- #region Server
--------------------

function TutorialManager:server_onCreate()
    g_tutorialManager = g_tutorialManager or self

    self.sv = {
        eventsReceived = {},
        saved = self.storage:load()
    }

    if not self.sv.saved then
        self.sv.saved = {
            tutorialsWatched = {},
            tutorialStep = 1
        }
    end

    self:sv_saveAndSync()
end

---save data and sync clientData
function TutorialManager:sv_saveAndSync()
    self.storage:save(self.sv.saved)
    local data = {
        tutorialStep = self.sv.saved.tutorialStep,
        tutorialsWatched = self.sv.saved.tutorialsWatched,
        eventsReceived = self.sv.eventsReceived
    }
    self.network:setClientData(data)
end

---@param tutorialName string
---mark tutorial as watched, so it won't trigger again
function TutorialManager:sv_e_watchedTutorial(tutorialName)
    self.sv.saved.tutorialsWatched[tutorialName] = true
    self:sv_saveAndSync()

    if tutorialName == "WindmillTutorial" then
        self:sv_e_questEvent("WindmillTutorialWatched")
    end
end

---starts a tutorial if it has not been seen already
---@param tutorialName string
function TutorialManager:sv_e_tryStartTutorial(tutorialName)
    if not self.sv.saved.tutorialsWatched[tutorialName] then
        self.network:sendToClients("cl_startTutorial", tutorialName)
    end
end

---send a quest event. Completed events will be saved.
---@param event string the quest event
function TutorialManager:sv_e_questEvent(event)
    if self.sv.eventsReceived[event] then return end

    self.sv.eventsReceived[event] = true

    ::checkAgain::
    local currentStep = tutorialSteps[self.sv.saved.tutorialStep]
    if not currentStep then return end

    local nextStep = true
    for _, event in ipairs(currentStep.events) do
        nextStep = nextStep and self.sv.eventsReceived[event]
    end

    if nextStep then
        if currentStep.tutorial then
            self:sv_e_tryStartTutorial(currentStep.tutorial)
        end

        self.sv.saved.tutorialStep = self.sv.saved.tutorialStep + 1
        goto checkAgain
    end

    self:sv_saveAndSync()
end

---**DEBUG** skip the tutorial
function TutorialManager.sv_skipTutorial()
    g_tutorialManager.sv.saved.tutorialStep = #tutorialSteps
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_saveDataAndSync")
end

-- #endregion

--------------------
-- #region Client
--------------------

function TutorialManager:client_onCreate()
    g_tutorialManager = g_tutorialManager or self

    self.cl = {
        activeTutorial = "",
        trackerHud = sm.gui.createQuestTrackerGui(),
        data = {
            tutorialsWatched = {},
            eventsReceived = {},
            tutorialStep = 1
        }
    }
    self.cl.trackerHud:open()
end

function TutorialManager:client_onClientDataUpdate(data)
    self.cl.data = data

    --update trackerHud
    local tutorialStep = self.cl.data.tutorialStep
    if tutorialStep <= #tutorialSteps then
        local events = tutorialSteps[tutorialStep].events
        local steps = {}
        -- get all steps
        for i = 1, #events, 1 do
            local event = events[i]
            local step = {
                name = "step" .. tostring(i),
                text = (self.cl.data.eventsReceived[event] and "#00dd00" or "") .. "- " .. language_tag(event .. "Event")
            }
            if event == "UpgraderBought" then
                step.text = step.text:format(sm.gui.getKeyBinding("Logbook"))
            end
            steps[#steps + 1] = step
        end
        -- display all steps on hud
        self.cl.trackerHud:trackQuest("tutorial", language_tag("TutorialQuestName"), true, steps)
    elseif self.cl.trackerHud then
        self.cl.trackerHud:destroy()
        self.cl.trackerHud = nil
    end
end

---start a pop-up tutorial
---@param tutorialName string name of the tutorial
function TutorialManager:cl_startTutorial(tutorialName)
    if self.cl.activeTutorial ~= tutorialName then
        if self.cl.tutorialGui then
            self.cl.tutorialGui:destroy()
        end

        self.cl.tutorialGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true,
            { isHud = true, isInteractive = false, needsCursor = false })

        self.cl.tutorialGui:setText("TextTitle", language_tag(tutorialName .. "Title"))

        local description = language_tag(tutorialName .. "Message")
        if tutorialName == "ClearOresTutorial" then
            description = description:format(sm.gui.getKeyBinding("Reload"))
        elseif tutorialName == "ShopTutorial" then
            description = description:format(sm.gui.getKeyBinding("Logbook"))
        elseif tutorialName == "SellTutorial" then
            description = description:format(sm.gui.getKeyBinding("NextCreateRotation"))
        end
        self.cl.tutorialGui:setText("TextMessage", description)

        local dismissText = string.format(language_tag("DismissTutorial"):format(sm.gui.getKeyBinding("Use")))
        self.cl.tutorialGui:setText("TextDismiss", dismissText)

        self.cl.tutorialGui:setImage("ImageTutorial", "$CONTENT_DATA/Gui/Images/Tutorials/" .. tutorialName .. ".png")
        self.cl.tutorialGui:setOnCloseCallback("cl_onCloseTutorialGui")
        self.cl.tutorialGui:open()

        self.cl.activeTutorial = tutorialName
    end
end

function TutorialManager:cl_onCloseTutorialGui()
    if self.cl.activeTutorial then
        self.network:sendToServer("sv_e_watchedTutorial", self.cl.activeTutorial)
    end
    self.cl.tutorialGui = nil
    self.cl.activeTutorial = nil
end

---check if ta tutorial pop up is open
---@return boolean open wether a tutorial pop up is open
function TutorialManager.cl_isTutorialPopUpActive()
    return g_tutorialManager.cl.tutorialGui and g_tutorialManager.cl.tutorialGui:isActive()
end

---closes the tutorial pop up
function TutorialManager.cl_closeTutorialPopUp()
    return g_tutorialManager.cl.tutorialGui:close()
end

---chekc if a specific tutorial event has been completed
---@param event string name of the tutorial event
---@return boolean completed whether the event has been completed
function TutorialManager.cl_isTutorialEventComplete(event)
    for step = 1, math.min(g_tutorialManager.cl.data.tutorialStep - 1, #tutorialSteps), 1 do
        if table.contains(tutorialSteps[step].events, event) then
            return true
        end
    end

    return g_tutorialManager.cl.data.eventsReceived[event]
end

---check if a specific tutorial event has been completed or is active
---@param event string name of the tutorial event
---@return boolean completed whether the event has been completed or is active
function TutorialManager.cl_isTutorialEventCompleteOrActive(event)
    if TutorialManager.cl_isTutorialEventComplete(event) then
        return true
    end

    --check if active
    local step = g_tutorialManager.cl.data.tutorialStep
    if step <= #tutorialSteps then
        if table.contains(tutorialSteps[step].events, event) then
            return true
        end
    end

    --neither
    return false
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class Tutorial
---@field events string[] events that must be received to finish this tutorial
---@field tutorial string tutorial that will be send to sv_e_tryStartTutorial upon completition

---@class TutorialManagerSv
---@field eventsReceived table<string, boolean>
---@field saved TutorialManagerSaveData saved data

---@class TutorialManagerSaveData
---@field tutorialsWatched table<string, boolean>
---@field tutorialStep integer index of the current tutorial in tutorialSteps

---@class TutorialManagerCl
---@field activeTutorial string name of the pop-up that is currently active
---@field trackerHud GuiInterface the interface that shows active quest events
---@field tutorialGui GuiInterface the interface that shows a pop up tutorial
---@field data TutorialManagerClientData

---@class TutorialManagerClientData
---@field tutorialsWatched table<string, boolean> table of tutorials that have been watched
---@field tutorialStep integer index of the current tutorial in tutorialSteps
---@field eventsReceived table<string, boolean> table of quest events that have been received

-- #endregion
