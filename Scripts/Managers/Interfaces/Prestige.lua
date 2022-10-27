dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")
dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Perks.lua")

---@class Prestige : Perks
Prestige = class(Perks)

function Prestige:sv_prestige()
	PrestigeManager.sv_prestige()
end

function Prestige:client_onCreate()
	if not g_cl_prestige then
		g_cl_prestige = self
	end

	local params = {}
	params.layout = "$CONTENT_DATA/Gui/Layouts/Prestige.layout"
	Interface.cient_onCreate(self, params)

	self.cl.gui:setButtonCallback("Reset", "cl_prestige")
	self.cl.gui:setButtonCallback("Perks", "cl_perks")

	Perks.client_onCreate(self)
end

function Prestige:client_onFixedUpdate()
	if self.cl.gui:isActive() then
		self:update_gui()
	end

	Perks.client_onFixedUpdate(self)
end

function Prestige:update_gui()
	local prestigeGain = PrestigeManager.getPrestigeGain()
	local newPrestige = PrestigeManager.cl_getPrestige() + prestigeGain
	self.cl.gui:setText("PrestigeGain",
		format_number({ format = "prestige", value = prestigeGain, prefix = "+ " }) .. "\n" ..
		"#ffffff(" ..
		format_number({ format = "prestige", value = newPrestige, color = "#ffffff", unit = " #dd6e00◊#ffffff" }) .. ")")
end

function Prestige.cl_e_open_gui()
	Prestige.update_gui(g_cl_prestige)

	g_cl_prestige.cl.gui:setText("Description", language_tag("PrestigeDescription"))
	g_cl_prestige.cl.gui:setText("Reset", language_tag("PrestigeResetButton"))

	Interface.cl_e_open_gui(g_cl_prestige)
end

function Prestige.cl_e_isGuiOpen()
	return Interface.cl_e_isGuiOpen(g_cl_prestige)
end

function Prestige.cl_close()
	Interface.cl_close(g_cl_prestige)
end

function Prestige:cl_prestige()
	self.cl.gui:close()

	self.cl.confirmPrestigeGui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout")
	self.cl.confirmPrestigeGui:setButtonCallback("Yes", "cl_onClearConfirmButtonClick")
	self.cl.confirmPrestigeGui:setButtonCallback("No", "cl_onClearConfirmButtonClick")
	self.cl.confirmPrestigeGui:setText("Title", language_tag("Prestige"))
	self.cl.confirmPrestigeGui:setText("Message", language_tag("PrestigeConfirmation"))
	self.cl.confirmPrestigeGui:open()
end

function Prestige:cl_onClearConfirmButtonClick(name)
	if name == "Yes" then
		self.network:sendToServer("sv_prestige")
	end
	self.cl.confirmPrestigeGui:close()
	self.cl.confirmPrestigeGui:destroy()
end


function Prestige:cl_perks()
	self.cl.gui:close()

	Perks.cl_openPerkGui(self)
end