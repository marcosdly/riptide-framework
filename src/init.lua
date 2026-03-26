--!strict
-- Riptide Framework Entry Point
local RunService = game:GetService("RunService")
local AsyncModule = require(script.shared.Utilities.Async)
local ComponentServiceModule = require(script.shared.ComponentService)
local NetworkModule = require(script.shared.Network)
local SignalModule = require(script.shared.Utilities.Signal)

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

if RunService:IsServer() then
	local Server = require(script.server.Core.ServerInitializer)
	Server._RiptideRef = Riptide
	Riptide.Server = Server
	Riptide.GetService = Riptide.GetModule
else
	local Client = require(script.client.Core.ClientInitializer)
	Client._RiptideRef = Riptide
	Riptide.Client = Client
	Riptide.GetController = Riptide.GetModule
end

Riptide.Network = NetworkModule

return Riptide
