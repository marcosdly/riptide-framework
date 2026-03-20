--!strict
-- Riptide/Network.lua
-- Shared Network Manager

local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

-- Types
type Callback = (...any) -> any
type HandlerMap = { [string]: { Callback } }

export type NetworkAPI = {
	Register: (funcName: string, callback: Callback) -> (),
	Unregister: (funcName: string, callback: Callback) -> (),
	FireClient: (player: Player, funcName: string, ...any) -> (),
	FireAllClients: (funcName: string, ...any) -> (),
	InvokeClient: (player: Player, funcName: string, ...any) -> any,
	FireServer: (funcName: string, ...any) -> (),
	InvokeServer: (funcName: string, ...any) -> any,
}

local Handlers: HandlerMap = {}

local Shared = script.Parent
local Remotes: Folder
local EventDispatcher: RemoteEvent
local FunctionDispatcher: RemoteFunction

-- Safe handler dispatch helper
local function DispatchHandlers(funcName: string, handlers: { Callback }, ...: any)
	for _, handler in ipairs(handlers) do
		task.spawn(function(...)
			local ok, err = xpcall(handler, debug.traceback, ...)
			if not ok then
				warn(string.format("[Network] Handler error for '%s': %s", funcName, tostring(err)))
			end
		end, ...)
	end
end

if IS_SERVER then
	local existingRemotes = Shared:FindFirstChild("Remotes")
	if not existingRemotes then
		Remotes = Instance.new("Folder")
		Remotes.Name = "Remotes"
		Remotes.Parent = Shared

		EventDispatcher = Instance.new("RemoteEvent")
		EventDispatcher.Name = "EventDispatcher"
		EventDispatcher.Parent = Remotes

		FunctionDispatcher = Instance.new("RemoteFunction")
		FunctionDispatcher.Name = "FunctionDispatcher"
		FunctionDispatcher.Parent = Remotes
	else
		Remotes = existingRemotes :: Folder
		EventDispatcher = Remotes:WaitForChild("EventDispatcher") :: RemoteEvent
		FunctionDispatcher = Remotes:WaitForChild("FunctionDispatcher") :: RemoteFunction
	end

	EventDispatcher.OnServerEvent:Connect(function(player: Player, funcName: string, ...: any)
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
else
	Remotes = Shared:WaitForChild("Remotes") :: Folder
	EventDispatcher = Remotes:WaitForChild("EventDispatcher") :: RemoteEvent
	FunctionDispatcher = Remotes:WaitForChild("FunctionDispatcher") :: RemoteFunction

	EventDispatcher.OnClientEvent:Connect(function(funcName: string, ...: any)
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
end

local Network = {}

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
		-- Clean up empty handler arrays to prevent memory growth
		if #handlers == 0 then
			Handlers[funcName] = nil
		end
	end
end

if IS_SERVER then
	function Network.FireClient(player: Player, funcName: string, ...: any)
		EventDispatcher:FireClient(player, funcName, ...)
	end

	function Network.FireAllClients(funcName: string, ...: any)
		EventDispatcher:FireAllClients(funcName, ...)
	end

	function Network.InvokeClient(player: Player, funcName: string, ...: any): any
		return FunctionDispatcher:InvokeClient(player, funcName, ...)
	end
else
	function Network.FireServer(funcName: string, ...: any)
		EventDispatcher:FireServer(funcName, ...)
	end

	function Network.InvokeServer(funcName: string, ...: any): any
		return FunctionDispatcher:InvokeServer(funcName, ...)
	end
end

return Network :: NetworkAPI
