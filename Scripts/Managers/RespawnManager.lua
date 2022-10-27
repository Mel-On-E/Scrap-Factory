dofile("$SURVIVAL_DATA/Scripts/game/managers/RespawnManager.lua")

---@class OldUnitManager : ScriptableObjectClass
OldRespawnManager = class(RespawnManager)

function RespawnManager.sv_setWorld(self, world)
	self.sv.overworld = world
end

function RespawnManager.sv_requestRespawnCharacter( self, player )
	SURVIVAL_DEV_SPAWN_POINT = SPAWN_POINT
	START_AREA_SPAWN_POINT = SPAWN_POINT
	OldRespawnManager.sv_requestRespawnCharacter( self, player )
end

function RespawnManager.sv_respawnCharacter( self, player, world )
	SURVIVAL_DEV_SPAWN_POINT = SPAWN_POINT
	START_AREA_SPAWN_POINT = SPAWN_POINT
	OldRespawnManager.sv_respawnCharacter( self, player, world )
end