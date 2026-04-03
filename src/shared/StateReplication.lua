--!strict
-- Riptide/shared/StateReplication.lua
-- Minimal server-authoritative state replication (global + per-player)

local task = task
if not task then
	task = require("@lune/task")
end

type Callback = (value: any) -> ()

type NetworkLike = {
	Register: (funcName: string, callback: (...any) -> any) -> (),
	Unregister: (funcName: string, callback: (...any) -> any) -> (),
	FireAllClients: ((funcName: string, ...any) -> ())?,
	FireClient: ((player: any, funcName: string, ...any) -> ())?,
	InvokeServer: ((funcName: string, ...any) -> any)?,
}

export type StateReplicationDeps = {
	IsServer: boolean,
	Network: NetworkLike,
}

export type StateReplicationAPI = {
	Events: {
		Delta: string,
		Snapshot: string,
	},
	_init: (self: StateReplicationAPI, deps: StateReplicationDeps) -> (),
	Set: (self: StateReplicationAPI, key: string, value: any) -> (),
	SetForPlayer: (self: StateReplicationAPI, player: any, key: string, value: any) -> (),
	UpdateForPlayer: (self: StateReplicationAPI, player: any, key: string, updater: (oldValue: any) -> any) -> any,
	Get: (self: StateReplicationAPI, key: string, player: any?) -> any,
	Subscribe: (self: StateReplicationAPI, key: string, callback: Callback) -> () -> (),
	RequestSync: (self: StateReplicationAPI) -> boolean,
	_resetForTests: (self: StateReplicationAPI) -> (),
}

local EVENT_DELTA = "__riptide_state_delta"
local EVENT_SNAPSHOT = "__riptide_state_snapshot"

local function shallowCopy(source: { [string]: any }): { [string]: any }
	return table.clone(source)
end

local function ensureServer(self: any)
	if not self._isServer then
		error("[StateReplication] This method is server-only.", 3)
	end
end

local function notify(self: any, key: string, value: any)
	local subscribers = self._subscribers[key]
	if not subscribers then
		return
	end

	for _, callback in ipairs(subscribers) do
		task.spawn(callback, value)
	end
end

local function applyClientDelta(self: any, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local key = payload.key
	local version = payload.version
	if type(key) ~= "string" or type(version) ~= "number" then
		return
	end

	local currentVersion = self._clientVersions[key] or 0
	if version <= currentVersion then
		return
	end

	self._clientVersions[key] = version
	self._clientState[key] = payload.value
	notify(self, key, payload.value)
end

local StateReplication = {} :: StateReplicationAPI

StateReplication.Events = {
	Delta = EVENT_DELTA,
	Snapshot = EVENT_SNAPSHOT,
}

StateReplication._initialized = false
StateReplication._isServer = false
StateReplication._network = nil :: NetworkLike?

StateReplication._globalState = {} :: { [string]: any }
StateReplication._globalVersions = {} :: { [string]: number }
StateReplication._playerState = setmetatable({}, { __mode = "k" }) :: { [any]: { [string]: any } }
StateReplication._playerVersions = setmetatable({}, { __mode = "k" }) :: { [any]: { [string]: number } }

StateReplication._clientState = {} :: { [string]: any }
StateReplication._clientVersions = {} :: { [string]: number }

StateReplication._subscribers = {} :: { [string]: { Callback } }
StateReplication._deltaHandler = nil :: ((...any) -> any)?
StateReplication._snapshotHandler = nil :: ((...any) -> any)?

function StateReplication:_resetForTests()
	if self._network and self._deltaHandler then
		self._network.Unregister(EVENT_DELTA, self._deltaHandler)
	end
	if self._network and self._snapshotHandler then
		self._network.Unregister(EVENT_SNAPSHOT, self._snapshotHandler)
	end

	self._initialized = false
	self._network = nil
	self._deltaHandler = nil
	self._snapshotHandler = nil
	self._isServer = false

	table.clear(self._globalState)
	table.clear(self._globalVersions)
	table.clear(self._clientState)
	table.clear(self._clientVersions)
	table.clear(self._subscribers)

	self._playerState = setmetatable({}, { __mode = "k" })
	self._playerVersions = setmetatable({}, { __mode = "k" })
end

function StateReplication:_init(deps: StateReplicationDeps)
	if not deps then
		error("[StateReplication] _init requires a deps table.", 2)
	end

	if type(deps.IsServer) ~= "boolean" then
		error("[StateReplication] _init requires deps.IsServer as boolean.", 2)
	end

	if not deps.Network then
		error("[StateReplication] _init requires deps.Network.", 2)
	end

	if self._initialized then
		self:_resetForTests()
	end

	self._isServer = deps.IsServer
	self._network = deps.Network
	self._initialized = true

	if self._isServer then
		self._snapshotHandler = function(player: any): any
			local playerState = self._playerState[player] or {}
			local playerVersions = self._playerVersions[player] or {}
			return {
				global = shallowCopy(self._globalState),
				globalVersions = shallowCopy(self._globalVersions),
				player = shallowCopy(playerState),
				playerVersions = shallowCopy(playerVersions),
			}
		end
		self._network.Register(EVENT_SNAPSHOT, self._snapshotHandler)
	else
		self._deltaHandler = function(payload: any)
			applyClientDelta(self, payload)
		end
		self._network.Register(EVENT_DELTA, self._deltaHandler)
		self:RequestSync()
	end
end

function StateReplication:Set(key: string, value: any)
	ensureServer(self)
	if type(key) ~= "string" then
		error("[StateReplication] Set requires key as string.", 2)
	end

	local nextVersion = (self._globalVersions[key] or 0) + 1
	self._globalVersions[key] = nextVersion
	self._globalState[key] = value

	if self._network and self._network.FireAllClients then
		self._network.FireAllClients(EVENT_DELTA, {
			key = key,
			value = value,
			version = nextVersion,
		})
	end
end

function StateReplication:SetForPlayer(player: any, key: string, value: any)
	ensureServer(self)
	if player == nil then
		error("[StateReplication] SetForPlayer requires player.", 2)
	end
	if type(key) ~= "string" then
		error("[StateReplication] SetForPlayer requires key as string.", 2)
	end

	if not self._playerState[player] then
		self._playerState[player] = {}
	end
	if not self._playerVersions[player] then
		self._playerVersions[player] = {}
	end

	local playerVersions = self._playerVersions[player] :: any
	local playerState = self._playerState[player] :: any

	local nextVersion = (playerVersions[key] or 0) + 1
	playerVersions[key] = nextVersion
	playerState[key] = value

	if self._network and self._network.FireClient then
		self._network.FireClient(player, EVENT_DELTA, {
			key = key,
			value = value,
			version = nextVersion,
		})
	end
end

function StateReplication:UpdateForPlayer(player: any, key: string, updater: (oldValue: any) -> any): any
	ensureServer(self)
	if player == nil then
		error("[StateReplication] UpdateForPlayer requires player.", 2)
	end
	if type(key) ~= "string" then
		error("[StateReplication] UpdateForPlayer requires key as string.", 2)
	end
	if type(updater) ~= "function" then
		error("[StateReplication] UpdateForPlayer requires updater function.", 2)
	end

	local oldValue = self:Get(key, player)
	local newValue = updater(oldValue)
	self:SetForPlayer(player, key, newValue)
	return newValue
end

function StateReplication:Get(key: string, player: any?): any
	if type(key) ~= "string" then
		error("[StateReplication] Get requires key as string.", 2)
	end

	if self._isServer then
		if player ~= nil then
			local playerState = self._playerState[player]
			if playerState and playerState[key] ~= nil then
				return playerState[key]
			end
		end
		return self._globalState[key]
	end

	return self._clientState[key]
end

function StateReplication:Subscribe(key: string, callback: Callback): () -> ()
	if type(key) ~= "string" then
		error("[StateReplication] Subscribe requires key as string.", 2)
	end
	if type(callback) ~= "function" then
		error("[StateReplication] Subscribe requires callback function.", 2)
	end

	if not self._subscribers[key] then
		self._subscribers[key] = {}
	end

	local subscribers = self._subscribers[key]
	table.insert(subscribers, callback)
	task.spawn(callback, self:Get(key))

	return function()
		local list = self._subscribers[key]
		if not list then
			return
		end

		for index, current in ipairs(list) do
			if current == callback then
				table.remove(list, index)
				break
			end
		end

		if #list == 0 then
			self._subscribers[key] = nil
		end
	end
end

function StateReplication:RequestSync(): boolean
	if self._isServer then
		return false
	end

	if not self._network or not self._network.InvokeServer then
		return false
	end

	local ok, snapshot = pcall(self._network.InvokeServer, EVENT_SNAPSHOT)
	if not ok or type(snapshot) ~= "table" then
		return false
	end

	local previousState = self._clientState
	self._clientState = {}
	self._clientVersions = {}

	for key, value in pairs(snapshot.global or {}) do
		self._clientState[key] = value
		self._clientVersions[key] = ((snapshot.globalVersions or {})[key] or 0)
	end

	for key, value in pairs(snapshot.player or {}) do
		self._clientState[key] = value
		self._clientVersions[key] = ((snapshot.playerVersions or {})[key] or 0)
	end

	for key, value in pairs(self._clientState) do
		if previousState[key] ~= value then
			notify(self, key, value)
		end
	end

	for key in pairs(previousState) do
		if self._clientState[key] == nil then
			notify(self, key, nil)
		end
	end

	return true
end

return StateReplication
