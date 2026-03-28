--!strict
-- Riptide/Server/Core/ServerInitializer.lua
-- Thin wrapper over ModuleLoader for server-side initialization.

local ModuleLoader = require(script.Parent.Parent.Parent.shared.ModuleLoader)

local ServerInitializer = {}
ServerInitializer._RiptideRef = nil :: any

local isLaunched = false

ServerInitializer.Launch = function(config: ModuleLoader.Config)
	if isLaunched then
		warn("🌊 [Riptide] Server framework already launched!")
		return
	end
	isLaunched = true

	ModuleLoader.Launch("Server", ServerInitializer._RiptideRef, config)
end

return ServerInitializer
