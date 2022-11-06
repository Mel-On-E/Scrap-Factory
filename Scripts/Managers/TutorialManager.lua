---@class TutorialManager : ScriptableObjectClass
TutorialManager = class()
TutorialManager.isSaveObject = true

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

function TutorialManager:server_onCreate()
    self.sv = {}
    self.sv.eventsReceived = {}

    self.sv.saved = self.storage:load()
    if not self.sv.saved then
        self.sv.saved = {}
        self.sv.saved.tutorialsWatched = {}
        self.sv.saved.tutorialProgress = 1
    end

    if not g_tutorialManager then
        g_tutorialManager = self
    end
end

function TutorialManager:sv_saveAndSync()
    self.storage:save(self.sv.saved)
    local data = {
        tutorialProgress = self.sv.saved.tutorialProgress,
        tutorialsWatched = self.sv.saved.tutorialsWatched,
        eventsReceived = self.sv.eventsReceived
    }
    self.network:setClientData(data)
end

function TutorialManager:sv_e_watchedTutorial(tutorialName)
    self.sv.saved.tutorialsWatched[tutorialName] = true
    self:sv_saveAndSync()

    if tutorialName == "WindmillTutorial" then
        self:sv_e_questEvent("WindmillTutorialWatched")
    end
end

function TutorialManager:sv_e_tryStartTutorial(tutorialName)
    if not self.sv.saved.tutorialsWatched[tutorialName] then
        self.network:sendToClients("cl_startTutorial", tutorialName)
    end
end

function TutorialManager:sv_e_questEvent(event)
    if self.sv.eventsReceived[event] then return end
    self.sv.eventsReceived[event] = true

    local currentStep = tutorialSteps[self.sv.saved.tutorialProgress]
    if not currentStep then return end

    local nextStep = true
    for _, event in ipairs(currentStep.events) do
        nextStep = nextStep and self.sv.eventsReceived[event]
    end

    if nextStep then
        if currentStep.tutorial then
            self:sv_e_tryStartTutorial(currentStep.tutorial)
        end

        self.sv.saved.tutorialProgress = self.sv.saved.tutorialProgress + 1
    end

    self:sv_saveAndSync()
end

function TutorialManager:client_onCreate()
    self.cl = {}
    self.cl.activeTutorial = ""
    self.cl.trackerHud = sm.gui.createQuestTrackerGui()
    self.cl.trackerHud:open()

    self.cl.data = {}
    self.cl.data.tutorialsWatched = {}
    self.cl.data.eventsReceived = {}
    self.cl.data.tutorialProgress = 1

    if not g_tutorialManager then
        g_tutorialManager = self
    end
end

function TutorialManager:client_onClientDataUpdate(data)
    self.cl.data = data

    --update trackerHud
    local tutorialProgress = self.cl.data.tutorialProgress
    print(tutorialProgress, #tutorialSteps)
    if tutorialProgress <= #tutorialSteps then
        local steps = {}
        for i = 1, #tutorialSteps[tutorialProgress].events, 1 do
            local event = tutorialSteps[tutorialProgress].events[i]
            local step = {
                name = "step" .. tostring(i),
                text = (self.cl.data.eventsReceived[event] and "#00dd00" or "") .. "- " .. language_tag(event .. "Event")
            }
            steps[#steps + 1] = step
        end

        self.cl.trackerHud:trackQuest("tutorial", language_tag("TutorialQuestName"), true, steps)

    elseif self.cl.trackerHud then
        self.cl.trackerHud:destroy()
        self.cl.trackerHud = nil
    end
end

function TutorialManager:cl_startTutorial(tutorialName)
    if self.cl.activeTutorial ~= tutorialName then
        self.cl.tutorialGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true,
            { isHud = true, isInteractive = false, needsCursor = false })

        self.cl.tutorialGui:setText("TextTitle", language_tag(tutorialName .. "Title"))
        local description = language_tag(tutorialName .. "Message")
        if tutorialName == "ClearOresTutorial" then
            description = description:format(sm.gui.getKeyBinding("Reload"))
        elseif tutorialName == "ShopTutorial" then
            description = description:format(sm.gui.getKeyBinding("Logbook"))
        end
        self.cl.tutorialGui:setText("TextMessage", description)

        local dismissText = string.format(language_tag("DismissTutorial"):format(sm.gui.getKeyBinding("Use")))
        self.cl.tutorialGui:setText("TextDismiss", dismissText)
        self.cl.tutorialGui:setImage("ImageTutorial", "$CONTENT_DATA/Gui/Images/Tutorials/" .. tutorialName .. ".png")
        self.cl.tutorialGui:setOnCloseCallback("cl_onCloseTutorialGui")
        self.cl.activeTutorial = tutorialName
        self.cl.tutorialGui:open()
    end
end

function TutorialManager:cl_onCloseTutorialGui()
    self.network:sendToServer("sv_e_watchedTutorial", self.cl.activeTutorial)
    self.cl.tutorialGui = nil
    self.cl.activeTutorial = nil
end

function TutorialManager.cl_isTutorialGuiActive()
    return g_tutorialManager.cl.tutorialGui and g_tutorialManager.cl.tutorialGui:isActive()
end

function TutorialManager.cl_closeTutorialGui()
    return g_tutorialManager.cl.tutorialGui:close()
end
