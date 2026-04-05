--!strict
-- Riptide/StateMachine.lua
-- Robust state orchestration utility.

local Signal = nil
do
	local success, result = pcall(function()
		return require(script.Parent.Utilities.Signal)
	end)

	if success then
		Signal = result
	else
		Signal = require("./Utilities/Signal")
	end
end

export type StateDefinition = {
	OnEnter: ((self: any, ...any) -> ())?,
	OnUpdate: ((self: any, dt: number) -> ())?,
	OnExit: ((self: any) -> ())?,
	[string]: any,
}

export type StateMachineConfig = {
	InitialState: string,
	States: { [string]: StateDefinition },
}

export type StateMachine = {
	OnStateChanged: typeof(Signal.new()),
	GetCurrentState: (self: StateMachine) -> string,
	TransitionTo: (self: StateMachine, newStateName: string, ...any) -> (),
	Update: (self: StateMachine, dt: number) -> (),
	Destroy: (self: StateMachine) -> (),
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(config: StateMachineConfig): StateMachine
	if not config then
		error("[StateMachine] Missing configuration.")
	end
	if type(config.States) ~= "table" then
		error("[StateMachine] Config must include a 'States' table.")
	end
	if not config.InitialState or not config.States[config.InitialState] then
		error(
			string.format("[StateMachine] Initial state '%s' is not defined in States.", tostring(config.InitialState))
		)
	end

	local self = setmetatable({
		_states = config.States,
		_currentStateName = config.InitialState,
		OnStateChanged = Signal.new(),
	}, StateMachine)

	local initialStateDef = self._states[self._currentStateName]
	if initialStateDef and type(initialStateDef.OnEnter) == "function" then
		initialStateDef.OnEnter(initialStateDef)
	end

	return (self :: any) :: StateMachine
end

function StateMachine:GetCurrentState(): string
	return self._currentStateName
end

function StateMachine:TransitionTo(newStateName: string, ...: any)
	if self._currentStateName == newStateName then
		return
	end

	local oldStateDef = self._states[self._currentStateName]
	local newStateDef = self._states[newStateName]

	if not newStateDef then
		warn(string.format("[StateMachine] Attempted to transition to unknown state: '%s'", newStateName))
		return
	end

	if oldStateDef and type(oldStateDef.OnExit) == "function" then
		oldStateDef.OnExit(oldStateDef)
	end

	local oldStateName = self._currentStateName
	self._currentStateName = newStateName

	if type(newStateDef.OnEnter) == "function" then
		newStateDef.OnEnter(newStateDef, ...)
	end

	self.OnStateChanged:Fire(oldStateName, newStateName)
end

function StateMachine:Update(dt: number)
	local currentStateDef = self._states[self._currentStateName]
	if currentStateDef and type(currentStateDef.OnUpdate) == "function" then
		currentStateDef.OnUpdate(currentStateDef, dt)
	end
end

function StateMachine:Destroy()
	local currentStateDef = self._states[self._currentStateName]
	if currentStateDef and type(currentStateDef.OnExit) == "function" then
		currentStateDef.OnExit(currentStateDef)
	end

	self.OnStateChanged:Destroy()
	table.clear(self._states)
	self._currentStateName = ""
end

return StateMachine
