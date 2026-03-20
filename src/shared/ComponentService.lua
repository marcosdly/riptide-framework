--!strict
-- Riptide/ComponentService.lua
-- A unified manager for Roblox CollectionService component objects (Server & Client)

local CollectionService = game:GetService("CollectionService")

export type ComponentClass = {
	new: (instance: Instance) -> any,
	Destroy: ((self: any) -> ())?,
}

export type ComponentServiceAPI = {
	_registry: { [Instance]: { [string]: any } },
	_destroyingConns: { [Instance]: { [string]: RBXScriptConnection } },
	Get: (self: ComponentServiceAPI, instance: Instance, tagName: string?) -> any?,
	_start: (self: ComponentServiceAPI, componentsFolder: Folder) -> (),
}

local ComponentService = {} :: ComponentServiceAPI

-- Using a Weak Table dictionary so that destroyed Instances don't memory leak their component wrappers.
-- Key = Instance, Value = Dictionary mapping TagNames to Component wrappers
ComponentService._registry = setmetatable({}, { __mode = "k" }) :: { [Instance]: { [string]: any } }

-- Track Destroying connections so we can clean them up when a tag is removed
ComponentService._destroyingConns = setmetatable({}, { __mode = "k" }) :: { [Instance]: { [string]: RBXScriptConnection } }

--[[ 
	Retrieves a registered Component wrapper attached to a specific instance.
	@param instance The Roblox instance referencing the original Tag
	@param tagName Optional tag name for deterministic lookup when instance has multiple tags
]]
function ComponentService:Get(instance: Instance, tagName: string?): any?
	local components = self._registry[instance]
	if not components then
		return nil
	end

	if tagName then
		return components[tagName]
	end

	-- Default: return the first component found
	for _, componentObj in pairs(components) do
		return componentObj
	end
	return nil
end

-- Internal cleanup helper
local function CleanupComponent(self: ComponentServiceAPI, instance: Instance, tagName: string)
	local components = self._registry[instance]
	if components then
		local componentObj = components[tagName]
		if componentObj then
			if type(componentObj.Destroy) == "function" then
				pcall(componentObj.Destroy, componentObj)
			end
			components[tagName] = nil
		end
	end

	-- Disconnect Destroying connection for this tag
	local conns = self._destroyingConns[instance]
	if conns then
		local conn = conns[tagName]
		if conn then
			conn:Disconnect()
			conns[tagName] = nil
		end
	end
end

-- Internal setup helper for a new component instance
local function SetupComponent(
	self: ComponentServiceAPI,
	instance: Instance,
	tagName: string,
	ComponentClass: ComponentClass
)
	local success, result = pcall(function()
		return ComponentClass.new(instance)
	end)

	if success and result then
		if not self._registry[instance] then
			self._registry[instance] = {}
		end
		self._registry[instance][tagName] = result

		-- Safety: also clean up when Instance is destroyed (even if tag isn't removed first)
		if not self._destroyingConns[instance] then
			self._destroyingConns[instance] = {}
		end
		self._destroyingConns[instance][tagName] = instance.Destroying:Connect(function()
			CleanupComponent(self, instance, tagName)
		end)
	else
		warn(string.format("[ComponentService] Failed to initialize instance of '%s':\n%s", tagName, tostring(result)))
	end
end

function ComponentService:_start(componentsFolder: Folder)
	for _, moduleScript in ipairs(componentsFolder:GetDescendants()) do
		if moduleScript:IsA("ModuleScript") then
			local tagName = moduleScript.Name
			local ok, ComponentClass = pcall(require, moduleScript)

			if not ok or type(ComponentClass) ~= "table" then
				warn(
					string.format(
						"[ComponentService] Failed to load component '%s':\n%s",
						tagName,
						tostring(ComponentClass)
					)
				)
				continue
			end

			-- Safety check for 'new'
			if type(ComponentClass.new) ~= "function" then
				warn(
					string.format(
						"[ComponentService] Skipping component '%s': missing 'new(instance)' constructor.",
						tagName
					)
				)
				continue
			end

			-- Bind to CollectionService added signals
			CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance: Instance)
				SetupComponent(self, instance, tagName, ComponentClass)
			end)

			-- Bind to CollectionService removed signals
			CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance: Instance)
				CleanupComponent(self, instance, tagName)
			end)

			-- Find any instances that already exist in the world right now
			for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
				SetupComponent(self, instance, tagName, ComponentClass)
			end
		end
	end
end

return ComponentService
