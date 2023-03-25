---Interface for every screen that can be opened via the `Hub` tool
---@class Interface : ScriptableObjectClass
Interface = class()

---Create new interface. Automatically creates functions for each button named after another interface to open it.
---@param layout string path to the layout file of the gui used by the interface
function Interface:client_onCreate(layout)
	self.cl = {
		gui = sm.gui.createGuiFromLayout(layout)
	}

	for _, sob in ipairs(g_Interfaces.scriptableObjectList) do
		self.cl.gui:setButtonCallback(string.lower(sob.classname), "cl_open" .. sob.classname)

		---@diagnostic disable-next-line: redefined-local
		self["cl_open" .. sob.classname] = function(self)
			self.cl.gui:close()
			self[sob.classname] = true
		end
	end

	self.cl.gui:setOnCloseCallback("cl_onGuiClosed")
end

---opens the gui of this interface. Sets text for all widgets named after Interfaces.
function Interface:cl_e_open_gui()
	for _, sob in ipairs(g_Interfaces.scriptableObjectList) do
		self.cl.gui:setText(string.lower(sob.classname), language_tag(sob.classname))
	end

	self.cl.gui:open()
end

---@return boolean open whether this interface is open
function Interface:cl_e_isGuiOpen()
	return self and self.cl.gui:isActive() or false
end

---closes the gui of the interface
function Interface:cl_close()
	if self ~= nil then
		self.cl.gui:close()
	end
end

---opens another interface if the interface had a variable set to true with its name
function Interface:cl_onGuiClosed()
	for _, sob in ipairs(g_Interfaces.scriptableObjectList) do
		if self[sob.classname] then
			_G[sob.classname].cl_e_open_gui()
		end
		self[sob.classname] = false
	end
end

---close all open interfaces
function Interface.cl_closeAllInterfaces()
	for _, sob in ipairs(g_Interfaces.scriptableObjectList) do
		_G[sob.classname].cl_close()
	end
end
