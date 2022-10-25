---@class Interface : ScriptableObjectClass

Interface = class()

function Interface:cient_onCreate(params)
	self.cl = {}
	self.cl.gui = sm.gui.createGuiFromLayout(params.layout)

	self.cl.gui:setButtonCallback("shop", "cl_openShop")
	self.cl.gui:setButtonCallback("research", "cl_openResearch")
	self.cl.gui:setButtonCallback("prestige", "cl_openPrestige")

	self.cl.gui:setOnCloseCallback("cl_onGuiClosed")
end

function Interface:cl_e_open_gui()
	self.cl.gui:setText("shop", language_tag("Shop"))
	self.cl.gui:setText("research", language_tag("Research"))
	self.cl.gui:setText("prestige", language_tag("Prestige"))

	self.cl.gui:open()
end

function Interface:cl_e_isGuiOpen()
	return self and self.cl.gui:isActive() or false
end

function Interface:cl_openResearch()
	self.cl.gui:close()
	self.research = true
end

function Interface:cl_openShop()
	self.cl.gui:close()
	self.shop = true
end

function Interface:cl_openPrestige()
	self.cl.gui:close()
	self.prestige = true
end

function Interface:cl_close()
	self.cl.gui:close()
end

function Interface:cl_onGuiClosed()
	if self.shop then
		Shop.cl_e_open_gui()
	elseif self.research then
		Research.cl_e_open_gui()
	elseif self.prestige then
		Prestige.cl_e_open_gui()
	end

	self.shop = false
	self.research = false
	self.prestige = false
end