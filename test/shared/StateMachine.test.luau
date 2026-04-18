--!strict
-- StateMachine Test Suite (frktest)

local Env = _G.TestEnv or require(script.Parent.TestEnv)
local task = Env.task

local frktest = Env.frktest
local test = frktest.test
local check = frktest.assert.check
local req = frktest.assert.require

local StateMachine = Env.RiptideShared.StateMachine

return function()
	test.suite("StateMachine", function()
		test.case("should fail to create without valid config", function()
			local ok1 = pcall(function()
				StateMachine.new(nil :: any)
			end)
			check.is_false(ok1)

			local ok2 = pcall(function()
				StateMachine.new({ InitialState = "Idle", States = {} })
			end)
			check.is_false(ok2) -- "Idle" is not defined
		end)

		test.case("should initialize and call OnEnter of InitialState", function()
			local entered = false
			local machine = StateMachine.new({
				InitialState = "Idle",
				States = {
					Idle = {
						OnEnter = function()
							entered = true
						end,
					},
				},
			})

			req.not_nil(machine)
			check.equal(machine:GetCurrentState(), "Idle")
			check.is_true(entered)
		end)

		test.case("should transition, trigger OnExit, OnEnter, and signal", function()
			local exitOld = false
			local enterNew = false
			local signalFired = false
			local oldObj = nil
			local oldS, newS = "", ""

			local FSM = StateMachine.new({
				InitialState = "A",
				States = {
					A = {
						OnExit = function(self)
							exitOld = true
							oldObj = self
						end,
					},
					B = {
						OnEnter = function(_, arg1, arg2)
							enterNew = true
							check.equal(arg1, 42)
							check.equal(arg2, "hello")
						end,
					},
				},
			})

			FSM.OnStateChanged:Connect(function(o, n)
				signalFired = true
				oldS = o
				newS = n
			end)

			FSM:TransitionTo("B", 42, "hello")
			task.wait() -- yield to allow Signal concurrent thread to fire

			check.is_true(exitOld)
			check.is_true(enterNew)
			check.is_true(signalFired)
			check.equal(oldObj, FSM._states["A"])
			check.equal(FSM:GetCurrentState(), "B")
			check.equal(oldS, "A")
			check.equal(newS, "B")
		end)

		test.case("should ignore transition to same state", function()
			local exits = 0
			local FSM = StateMachine.new({
				InitialState = "A",
				States = {
					A = {
						OnExit = function()
							exits += 1
						end,
					},
				},
			})

			FSM:TransitionTo("A")
			check.equal(exits, 0)
			check.equal(FSM:GetCurrentState(), "A")
		end)

		test.case("should pipe Update(dt) to currently active state", function()
			local aUpdates = 0
			local bUpdates = 0

			local FSM = StateMachine.new({
				InitialState = "A",
				States = {
					A = {
						OnUpdate = function(_, dt)
							aUpdates += 1
							check.equal(dt, 0.5)
						end,
					},
					B = {
						OnUpdate = function(_, _)
							bUpdates += 1
						end,
					},
				},
			})

			FSM:Update(0.5)
			FSM:Update(0.5)
			check.equal(aUpdates, 2)
			check.equal(bUpdates, 0)

			FSM:TransitionTo("B")
			FSM:Update(0.5)
			check.equal(aUpdates, 2)
			check.equal(bUpdates, 1)
		end)

		test.case("should Destroy cleanly", function()
			local exited = false
			local FSM = StateMachine.new({
				InitialState = "A",
				States = {
					A = {
						OnExit = function()
							exited = true
						end,
					},
				},
			})

			FSM:Destroy()
			check.is_true(exited)
			check.equal(FSM:GetCurrentState(), "")
			-- Checking that states table is cleared
			check.equal(next(FSM._states), nil)
		end)
	end)
end
