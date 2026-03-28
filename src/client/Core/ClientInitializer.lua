--!strict
-- Riptide/Client/Core/ClientInitializer.lua
-- Thin wrapper over ModuleLoader for client-side initialization.

local ModuleLoader = require(script.Parent.Parent.Parent.shared.ModuleLoader)

local ClientInitializer = {}
ClientInitializer._RiptideRef = nil :: any

local isLaunched = false

ClientInitializer.Launch = function(config: ModuleLoader.Config)
	if isLaunched then
		warn("🌊 [Riptide] Client framework already launched!")
		return
	end
	isLaunched = true

	ModuleLoader.Launch("Client", ClientInitializer._RiptideRef, config)
end

return ClientInitializer
