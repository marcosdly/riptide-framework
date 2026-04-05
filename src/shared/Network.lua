--!strict
-- Riptide/Network.lua
-- Shared Network Manager with Dependency Injection for testability.

local task = task
if not task then
	task = require("@lune/task")
end
type Callback = (...any) -> any
type HandlerMap = { [string]: { Callback } }
type Middleware = (...any) -> any

export type NetworkDeps = {
	IsServer: boolean,
	EventDispatcher: any,
	UnreliableEventDispatcher: any,
	FunctionDispatcher: any,
}

export type NetworkAPI = {
	_init: (deps: NetworkDeps) -> (),
	Register: (funcName: string, callback: Callback) -> (),
	Unregister: (funcName: string, callback: Callback) -> (),
	UseMiddleware: (scope: "server" | "client", middleware: Middleware) -> (),
	ClearMiddlewares: (scope: "server" | "client"?) -> (),
	FireClient: ((player: Player, funcName: string, ...any) -> ())?,
	FireAllClients: ((funcName: string, ...any) -> ())?,
	UnreliableFireClient: ((player: Player, funcName: string, ...any) -> ())?,
	UnreliableFireAllClients: ((funcName: string, ...any) -> ())?,
	InvokeClient: ((player: Player, funcName: string, ...any) -> any)?,
	FireServer: ((funcName: string, ...any) -> ())?,
	UnreliableFireServer: ((funcName: string, ...any) -> ())?,
	InvokeServer: ((funcName: string, ...any) -> any)?,
}

local Handlers: HandlerMap = {}

local EventDispatcher: any = nil
local UnreliableEventDispatcher: any = nil
local FunctionDispatcher: any = nil
local IS_SERVER: boolean = false
local EventConnection: any = nil
local UnreliableEventConnection: any = nil
local Middlewares = {
	server = {} :: { Middleware },
	client = {} :: { Middleware },
}

local function disconnectCurrentEventConnection()
	if EventConnection and type(EventConnection.Disconnect) == "function" then
		EventConnection:Disconnect()
	end
	EventConnection = nil
	if UnreliableEventConnection and type(UnreliableEventConnection.Disconnect) == "function" then
		UnreliableEventConnection:Disconnect()
	end
	UnreliableEventConnection = nil
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

local function runServerMiddlewareChain(player: any, funcName: string, terminal: Callback, ...: any): any
	local function step(index: number, ...: any): any
		local middleware = Middlewares.server[index]
		if middleware then
			local ok, result = xpcall(middleware, debug.traceback, player, funcName, function(...: any)
				return step(index + 1, ...)
			end, ...)
			if not ok then
				warn(string.format("[Network] Server middleware error for '%s': %s", funcName, tostring(result)))
				return nil
			end
			return result
		end
		return terminal(...)
	end

	return step(1, ...)
end

local function runClientMiddlewareChain(funcName: string, terminal: Callback, ...: any): any
	local function step(index: number, ...: any): any
		local middleware = Middlewares.client[index]
		if middleware then
			local ok, result = xpcall(middleware, debug.traceback, funcName, function(...: any)
				return step(index + 1, ...)
			end, ...)
			if not ok then
				warn(string.format("[Network] Client middleware error for '%s': %s", funcName, tostring(result)))
				return nil
			end
			return result
		end
		return terminal(...)
	end

	return step(1, ...)
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

	if not deps.UnreliableEventDispatcher then
		error("[Network] _init requires deps.UnreliableEventDispatcher.")
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
	UnreliableEventDispatcher = deps.UnreliableEventDispatcher
	FunctionDispatcher = deps.FunctionDispatcher

	if next(Handlers) then
		warn("[Network] _init called with active handlers — clearing existing handlers.")
	end

	-- Clear any previously registered handlers (for test re-initialization)
	table.clear(Handlers)
	table.clear(Middlewares.server)
	table.clear(Middlewares.client)

	if IS_SERVER then
		EventConnection = EventDispatcher.OnServerEvent:Connect(function(player: Player, funcName: string, ...: any)
			local handlers = Handlers[funcName]
			if handlers then
				runServerMiddlewareChain(player, funcName, function(...: any)
					DispatchHandlers(funcName, handlers, player, ...)
				end, ...)
			end
		end)

		if UnreliableEventDispatcher ~= EventDispatcher then
			UnreliableEventConnection = UnreliableEventDispatcher.OnServerEvent:Connect(
				function(player: Player, funcName: string, ...: any)
					local handlers = Handlers[funcName]
					if handlers then
						runServerMiddlewareChain(player, funcName, function(...: any)
							DispatchHandlers(funcName, handlers, player, ...)
						end, ...)
					end
				end
			)
		else
			UnreliableEventConnection = nil
		end

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
				return runServerMiddlewareChain(player, funcName, function(...: any)
					return handlers[1](player, ...)
				end, ...)
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

		Network.UnreliableFireClient = function(_player: Player, funcName: string, ...: any)
			UnreliableEventDispatcher:FireClient(_player, funcName, ...)
		end

		Network.UnreliableFireAllClients = function(funcName: string, ...: any)
			UnreliableEventDispatcher:FireAllClients(funcName, ...)
		end

		Network.InvokeClient = function(_player: Player, funcName: string, ...: any): any
			return FunctionDispatcher:InvokeClient(_player, funcName, ...)
		end

		-- Clear client APIs to prevent leakage between isolated tests
		Network.FireServer = nil
		Network.UnreliableFireServer = nil
		Network.InvokeServer = nil
	else
		EventConnection = EventDispatcher.OnClientEvent:Connect(function(funcName: string, ...: any)
			local handlers = Handlers[funcName]
			if handlers then
				runClientMiddlewareChain(funcName, function(...: any)
					DispatchHandlers(funcName, handlers, ...)
				end, ...)
			end
		end)

		if UnreliableEventDispatcher ~= EventDispatcher then
			UnreliableEventConnection = UnreliableEventDispatcher.OnClientEvent:Connect(
				function(funcName: string, ...: any)
					local handlers = Handlers[funcName]
					if handlers then
						runClientMiddlewareChain(funcName, function(...: any)
							DispatchHandlers(funcName, handlers, ...)
						end, ...)
					end
				end
			)
		else
			UnreliableEventConnection = nil
		end

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
				return runClientMiddlewareChain(funcName, function(...: any)
					return handlers[1](...)
				end, ...)
			end
			warn(string.format("[NetworkClient] Received invoke '%s' but no handler is registered.", funcName))
			return nil
		end

		Network.FireServer = function(funcName: string, ...: any)
			EventDispatcher:FireServer(funcName, ...)
		end

		Network.UnreliableFireServer = function(funcName: string, ...: any)
			UnreliableEventDispatcher:FireServer(funcName, ...)
		end

		Network.InvokeServer = function(funcName: string, ...: any): any
			return FunctionDispatcher:InvokeServer(funcName, ...)
		end

		-- Clear server APIs to prevent leakage between isolated tests
		Network.FireClient = nil
		Network.FireAllClients = nil
		Network.UnreliableFireClient = nil
		Network.UnreliableFireAllClients = nil
		Network.InvokeClient = nil
	end
end

function Network.UseMiddleware(scope: "server" | "client", middleware: Middleware)
	if scope ~= "server" and scope ~= "client" then
		error("[Network] UseMiddleware scope must be 'server' or 'client'.", 2)
	end
	if type(middleware) ~= "function" then
		error("[Network] UseMiddleware requires a middleware function.", 2)
	end
	table.insert((Middlewares :: any)[scope], middleware)
end

function Network.ClearMiddlewares(scope: "server" | "client"?)
	if scope == nil then
		table.clear(Middlewares.server)
		table.clear(Middlewares.client)
		return
	end

	if scope ~= "server" and scope ~= "client" then
		error("[Network] ClearMiddlewares scope must be 'server' or 'client'.", 2)
	end

	table.clear((Middlewares :: any)[scope])
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
