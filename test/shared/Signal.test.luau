--!strict
-- Signal Test Suite (frktest)

local Env = _G.TestEnv or require(script.Parent.TestEnv)
local task = Env.task

local frktest = Env.frktest
local test = frktest.test
local check = frktest.assert.check
local req = frktest.assert.require

local Signal = Env.RiptideShared.Signal

return function()
	test.suite("Signal", function()
		test.case("should create a new signal", function()
			local sig = Signal.new()
			req.not_nil(sig)
			check.equal(sig._head, nil)
		end)

		test.case("should connect to a function and fire", function()
			local sig = Signal.new()
			local fired = false
			local value = 0

			local conn = sig:Connect(function(v)
				fired = true
				value = v
			end)

			req.not_nil(conn)
			check.equal(conn.Connected, true)
			check.equal(sig._head, conn)

			sig:Fire(42)
			task.wait()

			check.equal(fired, true)
			check.equal(value, 42)
		end)

		test.case("should disconnect correctly and clear references", function()
			local sig = Signal.new()
			local count = 0

			local conn = sig:Connect(function()
				count += 1
			end)

			sig:Fire()
			task.wait()
			check.equal(count, 1)

			conn:Disconnect()
			check.equal(conn.Connected, false)
			check.equal(sig._head, nil)

			-- Verify references are cleared (memory leak prevention)
			check.equal((conn :: any)._signal, nil)
			check.equal((conn :: any)._fn, nil)
			check.equal((conn :: any)._next, nil)

			sig:Fire()
			task.wait()
			check.equal(count, 1) -- Should not trigger again
		end)

		test.case("should support Once (auto-disconnect after first fire)", function()
			local sig = Signal.new()
			local count = 0

			local conn = sig:Once(function()
				count += 1
			end)

			check.equal(conn.Connected, true)

			sig:Fire()
			task.wait()
			check.equal(count, 1)
			check.equal(conn.Connected, false)

			sig:Fire()
			task.wait()
			check.equal(count, 1) -- No second trigger
		end)

		test.case("should wait and yield correctly", function()
			local sig = Signal.new()
			local value1, value2

			task.spawn(function()
				value1, value2 = sig:Wait()
			end)

			req.not_nil(sig._head) -- Wait creates a temporary connection

			sig:Fire("Hello", "World")
			task.wait()

			check.equal(value1, "Hello")
			check.equal(value2, "World")
			check.equal(sig._head, nil) -- Auto-cleaned
		end)

		test.case("should disconnect all connections and clear references", function()
			local sig = Signal.new()
			local count1 = 0
			local count2 = 0

			local conn1 = sig:Connect(function()
				count1 += 1
			end)

			local conn2 = sig:Connect(function()
				count2 += 1
			end)

			req.not_nil(sig._head)
			check.equal(conn1.Connected, true)
			check.equal(conn2.Connected, true)

			sig:DisconnectAll()

			check.equal(sig._head, nil)
			check.equal(conn1.Connected, false)
			check.equal(conn2.Connected, false)
			check.equal((conn1 :: any)._fn, nil)
			check.equal((conn2 :: any)._fn, nil)

			sig:Fire()
			task.wait()

			check.equal(count1, 0)
			check.equal(count2, 0)
		end)

		test.case("should support Destroy and prevent further use", function()
			local sig = Signal.new()
			local conn = sig:Connect(function() end)
			check.equal(conn.Connected, true)

			sig:Destroy()

			check.equal(conn.Connected, false)
			check.equal(sig._head, nil)
		end)
	end)
end
