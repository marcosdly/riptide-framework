--!strict
-- Riptide/Network.lua
-- Shared Network Manager with Dependency Injection for testability.

local task = task
if not task then
	task = require("@lune/task")
end
type Callback = (...any) -> any
type HandlerMap = { [string]: { Callback } }

export type NetworkDeps = {
	IsServer: boolean,
	EventDispatcher: any,
	FunctionDispatcher: any,
}

export type NetworkAPI = {
	_init: (deps: NetworkDeps) -> (),
	Register: (funcName: string, callback: Callback) -> (),
	Unregister: (funcName: string, callback: Callback) -> (),
	FireClient: ((player: Player, funcName: string, ...any) -> ())?,
	FireAllClients: ((funcName: string, ...any) -> ())?,
	InvokeClient: ((player: Player, funcName: string, ...any) -> any)?,
	FireServer: ((funcName: string, ...any) -> ())?,
	InvokeServer: ((funcName: string, ...any) -> any)?,
}

local Handlers: HandlerMap = {}

local EventDispatcher: any = nil
local FunctionDispatcher: any = nil
local IS_SERVER: boolean = false
local EventConnection: any = nil

local function disconnectCurrentEventConnection()
	if EventConnection and type(EventConnection.Disconnect) == "function" then
		EventConnection:Disconnect()
	end
	EventConnection = nil
end

local function runHandler(handler: Callback, funcName: string, ...: any)
	local ok, err = xpcall(handler, debug.traceback, ...)
	if not ok then
		warn(string.format("[Network] Handler error for '%s': %s", funcName, tostring(err)))
	end
end

local function DispatchHandlers(funcName: string, handlers: { Callback }, ...: any)
	for _, handler in ipairs(handlers) do
		task.spawn(runHandler, handler, funcName, ...)
	end
end

local Network = {} :: NetworkAPI

function Network._init(deps: NetworkDeps)
	if not deps then
		error("[Network] _init requires a deps table.")
	end

	if type(deps.IsServer) ~= "boolean" then
		error("[Network] _init requires deps.IsServer as boolean.")
	end

	if not deps.EventDispatcher then
		error("[Network] _init requires deps.EventDispatcher.")
	end

	if not deps.FunctionDispatcher then
		error("[Network] _init requires deps.FunctionDispatcher.")
	end

	disconnectCurrentEventConnection()

	if FunctionDispatcher then
		FunctionDispatcher.OnServerInvoke = nil
		FunctionDispatcher.OnClientInvoke = nil
	end

	IS_SERVER = deps.IsServer
	EventDispatcher = deps.EventDispatcher
	FunctionDispatcher = deps.FunctionDispatcher

	-- Clear any previously registered handlers (for test re-initialization)
	table.clear(Handlers)

	if IS_SERVER then
		EventConnection = EventDispatcher.OnServerEvent:Connect(function(player: Player, funcName: string, ...: any)
			local handlers = Handlers[funcName]
			if handlers then
				DispatchHandlers(funcName, handlers, player, ...)
			end
		end)

		FunctionDispatcher.OnServerInvoke = function(player: Player, funcName: string, ...: any): any
			local handlers = Handlers[funcName]
			if handlers and handlers[1] then
				if #handlers > 1 then
					warn(
						string.format(
							"[NetworkServer] Multiple handlers registered for invoke '%s'. Only the first will be called.",
							funcName
						)
					)
				end
				return handlers[1](player, ...)
			end
			warn(string.format("[NetworkServer] Received invoke '%s' but no handler is registered.", funcName))
			return nil
		end

		Network.FireClient = function(_player: Player, funcName: string, ...: any)
			EventDispatcher:FireClient(_player, funcName, ...)
		end

		Network.FireAllClients = function(funcName: string, ...: any)
			EventDispatcher:FireAllClients(funcName, ...)
		end

		Network.InvokeClient = function(_player: Player, funcName: string, ...: any): any
			return FunctionDispatcher:InvokeClient(_player, funcName, ...)
		end

		-- Clear client APIs to prevent leakage between isolated tests
		Network.FireServer = nil
		Network.InvokeServer = nil
	else
		EventConnection = EventDispatcher.OnClientEvent:Connect(function(funcName: string, ...: any)
			local handlers = Handlers[funcName]
			if handlers then
				DispatchHandlers(funcName, handlers, ...)
			end
		end)

		FunctionDispatcher.OnClientInvoke = function(funcName: string, ...: any): any
			local handlers = Handlers[funcName]
			if handlers and handlers[1] then
				if #handlers > 1 then
					warn(
						string.format(
							"[NetworkClient] Multiple handlers registered for invoke '%s'. Only the first will be called.",
							funcName
						)
					)
				end
				return handlers[1](...)
			end
			warn(string.format("[NetworkClient] Received invoke '%s' but no handler is registered.", funcName))
			return nil
		end

		Network.FireServer = function(funcName: string, ...: any)
			EventDispatcher:FireServer(funcName, ...)
		end

		Network.InvokeServer = function(funcName: string, ...: any): any
			return FunctionDispatcher:InvokeServer(funcName, ...)
		end

		-- Clear server APIs to prevent leakage between isolated tests
		Network.FireClient = nil
		Network.FireAllClients = nil
		Network.InvokeClient = nil
	end
end

function Network.Register(funcName: string, callback: Callback)
	if not Handlers[funcName] then
		Handlers[funcName] = {}
	end
	table.insert(Handlers[funcName], callback)
end

function Network.Unregister(funcName: string, callback: Callback)
	local handlers = Handlers[funcName]
	if handlers then
		for i, handler in ipairs(handlers) do
			if handler == callback then
				table.remove(handlers, i)
				break
			end
		end
		if #handlers == 0 then
			Handlers[funcName] = nil
		end
	end
end

return Network :: NetworkAPI
