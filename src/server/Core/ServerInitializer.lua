--!strict
-- Riptide/Server/Core/ServerInitializer.lua
local ServerInitializer = {}
ServerInitializer._RiptideRef = nil

local loadedModules = {}
local isLaunched = false

type ModuleFolders = Folder | { Folder }

type Config = {
	ModulesFolder: ModuleFolders,
	SharedModulesFolder: ModuleFolders?,
	ComponentsFolder: Folder?,
}

local function GetCanonicalModuleId(modulesFolder: Folder, moduleScript: ModuleScript): string
	local parts = { moduleScript.Name }
	local current: Instance? = moduleScript.Parent

	while current and current ~= modulesFolder do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end

	if current ~= modulesFolder then
		return moduleScript.Name
	end

	return table.concat(parts, "/")
end

local function NormalizeFolders(input: ModuleFolders?, fieldName: string): { Folder }
	if input == nil then
		return {}
	end

	if typeof(input) == "Instance" then
		local instanceInput = input :: Instance
		if instanceInput:IsA("Folder") then
			return { instanceInput }
		end

		error(string.format("[Riptide] %s must be a Folder or array of Folder values.", fieldName))
	end

	if type(input) ~= "table" then
		error(string.format("[Riptide] %s must be a Folder or array of Folder values.", fieldName))
	end

	local folders = {} :: { Folder }
	for i, folder in ipairs(input :: { any }) do
		if typeof(folder) ~= "Instance" or not (folder :: Instance):IsA("Folder") then
			error(string.format("[Riptide] %s[%d] must be a Folder.", fieldName, i))
		end
		table.insert(folders, folder :: Folder)
	end

	return folders
end

local function LoadModules(folder: Folder, seenModuleScripts: { [ModuleScript]: boolean })
	local riptide = ServerInitializer._RiptideRef
	for _, instance in ipairs(folder:GetDescendants()) do
		if instance:IsA("ModuleScript") then
			if seenModuleScripts[instance] then
				continue
			end
			seenModuleScripts[instance] = true

			local ok, module = xpcall(require, debug.traceback, instance)
			if ok and type(module) == "table" then
				local canonicalId = GetCanonicalModuleId(folder, instance)
				if riptide._modules[canonicalId] ~= nil then
					warn(
						string.format(
							"[Server] Duplicate canonical module id '%s'. Skipping '%s'.",
							canonicalId,
							instance:GetFullName()
						)
					)
					continue
				end

				riptide._modules[canonicalId] = module

				local aliasName = instance.Name
				if aliasName ~= canonicalId then
					local aliasState = riptide._moduleAliases[aliasName]
					if aliasState == nil then
						riptide._moduleAliases[aliasName] = canonicalId
					elseif aliasState ~= canonicalId and aliasState ~= false then
						riptide._moduleAliases[aliasName] = false
						warn(
							string.format(
								"[Server] Module alias conflict for '%s'. Use canonical module id (example: '%s').",
								aliasName,
								canonicalId
							)
						)
					end
				end

				table.insert(loadedModules, {
					name = canonicalId,
					module = module,
				})
			else
				warn("[Server] Failed to load module: " .. instance.Name .. "\n" .. tostring(module))
			end
		end
	end
end

ServerInitializer.Launch = function(config: Config)
	if isLaunched then
		warn("🌊 [Riptide] Server framework already launched!")
		return
	end
	isLaunched = true

	if not config or not config.ModulesFolder then
		error("[Riptide] ServerInitializer.Launch requires a config table with a ModulesFolder.")
	end

	local riptide = ServerInitializer._RiptideRef
	if not riptide then
		error("[Riptide] ServerInitializer missing _RiptideRef. Ensure it's launched through the main Riptide module.")
	end

	print("🌊 [Riptide] Server Initialization Started...")

	-- 1. LOAD PHASE
	local seenModuleScripts = {} :: { [ModuleScript]: boolean }
	for _, sharedFolder in ipairs(NormalizeFolders(config.SharedModulesFolder, "SharedModulesFolder")) do
		LoadModules(sharedFolder, seenModuleScripts)
	end

	for _, modulesFolder in ipairs(NormalizeFolders(config.ModulesFolder, "ModulesFolder")) do
		LoadModules(modulesFolder, seenModuleScripts)
	end

	if config.ComponentsFolder then
		riptide.ComponentService:_start(config.ComponentsFolder)
	end

	-- 2. INIT PHASE
	for _, data in ipairs(loadedModules) do
		if type(data.module.Init) == "function" then
			local ok, err = xpcall(data.module.Init, debug.traceback, data.module, riptide)
			if not ok then
				warn(string.format("[Server] ❌ Error initializing %s:\n%s", data.name, tostring(err)))
			end
		end
	end

	-- 3. START PHASE
	for _, data in ipairs(loadedModules) do
		if type(data.module.Start) == "function" then
			task.spawn(function()
				local ok, err = xpcall(data.module.Start, debug.traceback, data.module, riptide)
				if not ok then
					warn(string.format("[Server] ❌ Error starting %s:\n%s", data.name, tostring(err)))
				end
			end)
		end
	end

	-- Free references after init is complete
	table.clear(loadedModules)

	print("🌊 [Riptide] ✅ Server Ready.")
end

return ServerInitializer
