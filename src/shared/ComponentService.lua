--!strict
-- Riptide/ComponentService.lua
-- A unified manager for Roblox CollectionService component objects (Server & Client)
-- Supports Dependency Injection for testability.

export type ComponentClass = {
	new: (instance: Instance) -> any,
	Destroy: ((self: any) -> ())?,
}

export type ComponentServiceDeps = {
	CollectionService: any,
}

export type ComponentServiceAPI = {
	_registry: { [Instance]: { [string]: any } },
	_destroyingConns: { [Instance]: { [string]: RBXScriptConnection } },
	_tagListeners: { [string]: { added: RBXScriptConnection, removed: RBXScriptConnection } },
	_isStarted: boolean,
	_collectionService: any?,
	Get: (self: ComponentServiceAPI, instance: Instance, tagName: string?) -> any?,
	_init: (self: ComponentServiceAPI, deps: ComponentServiceDeps) -> (),
	_start: (self: ComponentServiceAPI, componentsFolder: Folder) -> (),
}

local ComponentService = {} :: ComponentServiceAPI

ComponentService._registry = setmetatable({}, { __mode = "k" }) :: { [Instance]: { [string]: any } }
ComponentService._destroyingConns = setmetatable({}, { __mode = "k" }) :: { [Instance]: { [string]: RBXScriptConnection } }
ComponentService._tagListeners = {} :: { [string]: { added: RBXScriptConnection, removed: RBXScriptConnection } }
ComponentService._isStarted = false
ComponentService._collectionService = nil
ComponentService._suppressWarnings = false

function ComponentService:_init(deps: ComponentServiceDeps)
	self._collectionService = deps.CollectionService
end

function ComponentService:Get(instance: Instance, tagName: string?): any?
	local components = self._registry[instance]
	if not components then
		return nil
	end

	if tagName then
		return components[tagName]
	end

	local selectedComponent = nil
	local count = 0

	for _, componentObj in pairs(components) do
		count += 1
		if count == 1 then
			selectedComponent = componentObj
		end
	end

	if count == 0 then
		return nil
	end

	if count == 1 then
		return selectedComponent
	end

	if not (self :: any)._suppressWarnings then
		warn(
			string.format(
				"[ComponentService] Get(instance) is ambiguous (%d components found). Pass an explicit tagName.",
				count
			)
		)
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
	local componentsForInstance = self._registry[instance]
	if componentsForInstance and componentsForInstance[tagName] ~= nil then
		return
	end

	local success, result = pcall(function()
		return ComponentClass.new(instance)
	end)

	if success and result then
		if not self._registry[instance] then
			self._registry[instance] = {}
		end
		self._registry[instance][tagName] = result

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
	if self._isStarted then
		if not (self :: any)._suppressWarnings then
			warn("[ComponentService] _start called more than once. Ignoring duplicate start.")
		end
		return
	end

	self._isStarted = true

	-- Use injected CollectionService, falling back to game:GetService for backward compat
	local cs = self._collectionService
	if not cs then
		cs = game:GetService("CollectionService")
		self._collectionService = cs
	end

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

			if type(ComponentClass.new) ~= "function" then
				warn(
					string.format(
						"[ComponentService] Skipping component '%s': missing 'new(instance)' constructor.",
						tagName
					)
				)
				continue
			end

			local addedConn = cs:GetInstanceAddedSignal(tagName):Connect(function(instance: Instance)
				SetupComponent(self, instance, tagName, ComponentClass)
			end)

			local removedConn = cs:GetInstanceRemovedSignal(tagName):Connect(function(instance: Instance)
				CleanupComponent(self, instance, tagName)
			end)

			self._tagListeners[tagName] = {
				added = addedConn,
				removed = removedConn,
			}

			for _, instance in ipairs(cs:GetTagged(tagName)) do
				SetupComponent(self, instance, tagName, ComponentClass)
			end
		end
	end
end

return ComponentService
