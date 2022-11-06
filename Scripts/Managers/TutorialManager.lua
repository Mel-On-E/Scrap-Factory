---@class TutorialManager : ScriptableObjectClass
TutorialManager = class()
TutorialManager.isSaveObject = true

function TutorialManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load()
    if not self.sv.saved then
        self.sv.saved = {}
        self.sv.saved.tutorialsWatched = {}
    end

    if not g_tutorialManager then
        g_tutorialManager = self
    end
end

function TutorialManager:sv_e_watchedTutorial(tutorialName)
    self.sv.saved.tutorialsWatched[tutorialName] = true
    self.storage:save(self.sv.saved)
    self.network:setClientData(self.sv.saved)
end

function TutorialManager:sv_e_tryStartTutorial(tutorialName)
    if not self.sv.saved.tutorialsWatched[tutorialName] then
        self.network:sendToClients("cl_startTutorial", tutorialName)
    end
end

function TutorialManager:client_onCreate()
    self.cl = {}
    self.cl.activeTutorial = ""

    self.cl.data = {}
    self.cl.data.tutorialsWatched = {}

    if not g_tutorialManager then
        g_tutorialManager = self
    end
end

function TutorialManager:client_onClientDataUpdate(data)
    self.cl.data = data
end

function TutorialManager:cl_startTutorial(tutorialName)
    if self.cl.activeTutorial ~= tutorialName then
        self.cl.tutorialGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true,
            { isHud = true, isInteractive = false, needsCursor = false })
        self.cl.tutorialGui:setText("TextTitle", language_tag(tutorialName .. "Title"))
        self.cl.tutorialGui:setText("TextMessage",
            language_tag(tutorialName .. "Message"):format(sm.gui.getKeyBinding("Reload")))
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
