---@class Interface : ScriptableObjectClass
Interface = class()

function Interface:client_onCreate(params)
	self.cl = {}
	self.cl.gui = sm.gui.createGuiFromLayout(params.layout)

	for _, sob in ipairs(g_sobSet.scriptableObjectList) do
		self.cl.gui:setButtonCallback(string.lower(sob.classname), "cl_open" .. sob.classname)

		self["cl_open" .. sob.classname] = function(self)
			self.cl.gui:close()
			self[sob.classname] = true
		end
	end

	self.cl.gui:setOnCloseCallback("cl_onGuiClosed")
end

function Interface:cl_e_open_gui()
	for _, sob in ipairs(g_sobSet.scriptableObjectList) do
		self.cl.gui:setText(string.lower(sob.classname), language_tag(sob.classname))
	end

	self.cl.gui:open()
end

function Interface:cl_e_isGuiOpen()
	return self and self.cl.gui:isActive() or false
end

function Interface:cl_close()
	if self ~= nil then
		self.cl.gui:close()
	end
end

function Interface:cl_onGuiClosed()
	for _, sob in ipairs(g_sobSet.scriptableObjectList) do
		if self[sob.classname] then
			_G[sob.classname].cl_e_open_gui()
		end
		self[sob.classname] = false
	end
end

function Interface.cl_closeAllInterfaces()
	for _, sob in ipairs(g_sobSet.scriptableObjectList) do
		_G[sob.classname].cl_close()
	end
end
