---@class Prestige : ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")

Prestige = class(Interface)

function Prestige:client_onCreate()
	if not g_cl_prestige then
		g_cl_prestige = self
	end

	local params = {}
	params.layout = "$CONTENT_DATA/Gui/Layouts/Prestige.layout"
	Interface.cient_onCreate(self, params)

	self.cl.gui:setButtonCallback("Reset", "cl_prestige")
end

function Prestige:client_onFixedUpdate()
	if self.cl.gui:isActive() then
		self:update_gui()
	end
end

function Prestige:update_gui()
	self.cl.gui:setText("PrestigeGain", format_number({format = "prestige", value = PrestigeManager.getPrestigeGain()}))
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

function Prestige.cl_prestige()
	print("prestige button press")
end