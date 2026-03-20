--!strict
-- Riptide/Client/Core/ClientInitializer.lua
local ClientInitializer = {}
ClientInitializer._RiptideRef = nil

local loadedModules = {}
local isLaunched = false

type Config = {
	ModulesFolder: Folder,
	ComponentsFolder: Folder?,
}

local function LoadModules(folder: Folder)
	local riptide = ClientInitializer._RiptideRef
	for _, instance in ipairs(folder:GetDescendants()) do
		if instance:IsA("ModuleScript") then
			local ok, module = xpcall(require, debug.traceback, instance)
			if ok and type(module) == "table" then
				riptide._modules[instance.Name] = module
				table.insert(loadedModules, {
					name = instance.Name,
					module = module,
				})
			else
				warn("[Client] Failed to load module: " .. instance.Name .. "\n" .. tostring(module))
			end
		end
	end
end

ClientInitializer.Launch = function(config: Config)
	if isLaunched then
		warn("🌊 [Riptide] Client framework already launched!")
		return
	end
	isLaunched = true

	if not config or not config.ModulesFolder then
		error("[Riptide] ClientInitializer.Launch requires a config table with a ModulesFolder.")
	end

	local riptide = ClientInitializer._RiptideRef
	if not riptide then
		error("[Riptide] ClientInitializer missing _RiptideRef. Ensure it's launched through the main Riptide module.")
	end

	print("[Client] Initialization started...")

	-- 1. LOAD PHASE
	LoadModules(config.ModulesFolder)

	if config.ComponentsFolder then
		riptide.ComponentService:_start(config.ComponentsFolder)
	end

	-- 2. INIT PHASE
	-- Execute Init methods synchronously.
	for _, data in ipairs(loadedModules) do
		if type(data.module.Init) == "function" then
			-- Wrap in pcall to prevent one module's error from breaking the framework
			local ok, err = xpcall(data.module.Init, debug.traceback, data.module, riptide)
			if not ok then
				warn(string.format("[Client] ❌ Error initializing %s:\n%s", data.name, tostring(err)))
			end
		end
	end

	-- 3. START PHASE
	-- Modules are now initialized and can safely interact with each other.
	for _, data in ipairs(loadedModules) do
		if type(data.module.Start) == "function" then
			task.spawn(function()
				local ok, err = xpcall(data.module.Start, debug.traceback, data.module, riptide)
				if not ok then
					warn(string.format("[Client] ❌ Error starting %s:\n%s", data.name, tostring(err)))
				end
			end)
		end
	end

	-- Free references after init is complete
	table.clear(loadedModules)

	print("[Client] ✅ Initialization completed.")
end

return ClientInitializer
