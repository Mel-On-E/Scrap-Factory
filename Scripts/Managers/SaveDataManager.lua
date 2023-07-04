---Manages variables that need to be saved
---@class SaveDataManager : ScriptableObjectClass
---@field sv SaveDataManagerSv
---@field cl SaveDataManagerCl
SaveDataManager = class()
SaveDataManager.isSaveObject = true

--------------------
-- #region Server
--------------------

function SaveDataManager:server_onCreate()
    g_saveDataManager = g_saveDataManager or self

    self.sv = {
        saved = self.storage:load() or {
            dropPlusPlus = 1
        }
    }
    self:sv_saveDataAndSync()
end

function SaveDataManager:sv_saveDataAndSync()
    self.storage:save(self.sv.saved)
    self.network:setClientData(self.sv.saved)
end

---Get a saved value
---@param name string name of the saved value
---@return any value the saved value
function SaveDataManager.Sv_getData(name)
    return g_saveDataManager.sv.saved[name]
end

---Set saved value
---@param name string name of the saved value
---@param data any new data of the saved value
function SaveDataManager.Sv_setData(name, data)
    g_saveDataManager.sv.saved[name] = data
    sm.event.sendToScriptableObject(g_saveDataManager.scriptableObject, "sv_saveDataAndSync")
end

-- #endregion

--------------------
-- #region Client
--------------------

function SaveDataManager:client_onCreate()
    g_saveDataManager = g_saveDataManager or self

    self.cl = {}
end

function SaveDataManager:client_onClientDataUpdate(data)
    self.cl.saved = data
end

-- #endregion

--------------------
-- #region Server
--------------------

---@class SaveDataManagerSv
---@field saved SaveDataManagerSaved

---@class SaveDataManagerSaved
---@field dropPlusPlus integer the value of a drop++. Increases by 1 for every drop++ dropped

---@class SaveDataManagerCl
---@field saved SaveDataManagerSaved

-- #endregion
