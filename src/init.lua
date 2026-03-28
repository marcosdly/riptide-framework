--!strict
-- Riptide Framework Entry Point
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local AsyncModule = require(script.shared.Utilities.Async)
local ComponentServiceModule = require(script.shared.ComponentService)
local NetworkModule = require(script.shared.Network)
local SignalModule = require(script.shared.Utilities.Signal)

local IS_SERVER = RunService:IsServer()

export type Riptide = {
	Network: NetworkModule.NetworkAPI,
	Signal: typeof(SignalModule),
	Async: typeof(AsyncModule),
	ComponentService: ComponentServiceModule.ComponentServiceAPI,
	GetModule: (name: string) -> any,
	GetService: (name: string) -> any,
	GetController: (name: string) -> any,
	Server: any,
	Client: any,
	_modules: { [string]: any },
	_moduleAliases: { [string]: string | false },
}

local Riptide = {} :: Riptide

Riptide._modules = {} :: { [string]: any }
Riptide._moduleAliases = {} :: { [string]: string | false }
Riptide.Signal = SignalModule
Riptide.Async = AsyncModule
Riptide.ComponentService = ComponentServiceModule

function Riptide.GetModule(name: string): any
	local module = Riptide._modules[name]
	if module then
		return module
	end

	local aliasValue = Riptide._moduleAliases[name]
	if aliasValue == false then
		warn(
			string.format(
				"🌊 [Riptide] Ambiguous module alias '%s'. Use canonical path id (example: 'Folder/%s').",
				name,
				name
			)
		)
		return nil
	end

	if type(aliasValue) == "string" then
		module = Riptide._modules[aliasValue]
		if module then
			return module
		end
	end

	if not module then
		warn(string.format("🌊 [Riptide] Failed to get module: '%s' is not registered!", name))
	end
	return module
end

-- Initialize ComponentService with real CollectionService
ComponentServiceModule:_init({
	CollectionService = CollectionService,
})

-- Initialize Network with real Remotes
local Shared = script.shared
local Remotes: Folder
local EventDispatcher: RemoteEvent
local FunctionDispatcher: RemoteFunction

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
else
	Remotes = Shared:WaitForChild("Remotes") :: Folder
	EventDispatcher = Remotes:WaitForChild("EventDispatcher") :: RemoteEvent
	FunctionDispatcher = Remotes:WaitForChild("FunctionDispatcher") :: RemoteFunction
end

NetworkModule._init({
	IsServer = IS_SERVER,
	EventDispatcher = EventDispatcher,
	FunctionDispatcher = FunctionDispatcher,
})

Riptide.Network = NetworkModule

-- Wire up side-specific initializers and lookup guards
if IS_SERVER then
	local Server = require(script.server.Core.ServerInitializer)
	Server._RiptideRef = Riptide
	Riptide.Server = Server
	Riptide.GetService = Riptide.GetModule
	Riptide.GetController = function()
		error("🌊 [Riptide] GetController is not available on the server. Use GetService instead.")
	end
else
	local Client = require(script.client.Core.ClientInitializer)
	Client._RiptideRef = Riptide
	Riptide.Client = Client
	Riptide.GetController = Riptide.GetModule
	Riptide.GetService = function()
		error("🌊 [Riptide] GetService is not available on the client. Use GetController instead.")
	end
end

return Riptide
