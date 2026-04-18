--!strict
-- Network Test Suite (frktest)

local Env = _G.TestEnv or require(script.Parent.TestEnv)
local task = Env.task

local frktest = Env.frktest
local test = frktest.test
local check = frktest.assert.check

local MockRemoteEvent = Env.Mocks.MockRemoteEvent
local MockRemoteFunction = Env.Mocks.MockRemoteFunction
local Network = Env.RiptideShared.Network

return function()
	test.suite("Network (Server Mode)", function()
		test.case("should initialize in server mode and expose server API", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local api = Network :: any
			check.not_nil(api.FireClient)
			check.not_nil(api.FireAllClients)
			check.not_nil(api.InvokeClient)
		end)

		test.case("should register and unregister handlers", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local called = false
			local function handler()
				called = true
			end

			Network.Register("TestEvent", handler)
			Network.Unregister("TestEvent", handler)

			-- Should not throw
			check.equal(called, false)
		end)

		test.case("should dispatch events to registered handlers", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local receivedPlayer = nil
			local receivedData = nil

			Network.Register("PlayerAction", function(player, data)
				receivedPlayer = player
				receivedData = data
			end)

			-- Simulate client sending event to server
			mockEvent.OnServerEvent:Fire("MockPlayer", "PlayerAction", "jump")
			task.wait()

			check.equal(receivedPlayer, "MockPlayer")
			check.equal(receivedData, "jump")
		end)

		test.case("should fire events to clients", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local api = Network :: any
			api.FireClient("Player1", "Reward", 100)

			check.equal(#mockEvent._firedClient, 1)
			check.equal(mockEvent._firedClient[1].player, "Player1")
		end)

		test.case("should handle invoke with registered handler", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			Network.Register("GetData", function(_player, key)
				return "value_" .. key
			end)

			-- Simulate the invoke path
			local result = mockFunction.OnServerInvoke("MockPlayer", "GetData", "score")
			check.equal(result, "value_score")
		end)

		test.case("should clean up empty handler entries after unregister", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local function handler() end
			Network.Register("CleanupTest", handler)
			Network.Unregister("CleanupTest", handler)

			-- Re-register should work without issues
			Network.Register("CleanupTest", handler)
			Network.Unregister("CleanupTest", handler)
		end)

		test.case("should not duplicate event dispatch after re-init", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local callCount = 0
			Network.Register("ReinitEvent", function()
				callCount += 1
			end)

			mockEvent.OnServerEvent:Fire("MockPlayer", "ReinitEvent")
			task.wait()

			check.equal(callCount, 1)
		end)

		test.case("should apply server middleware to incoming events", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			Network.UseMiddleware("server", function(_player, _funcName, next, value)
				return next(string.upper(value))
			end)

			local received = nil
			Network.Register("MiddlewareEvent", function(_player, value)
				received = value
			end)

			mockEvent.OnServerEvent:Fire("MockPlayer", "MiddlewareEvent", "hello")
			task.wait()

			check.equal(received, "HELLO")
		end)

		test.case("should allow server middleware to block invoke", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = true,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			Network.UseMiddleware("server", function(_player, _funcName, _next, _key)
				return "blocked"
			end)

			Network.Register("GuardedInvoke", function(_player, key)
				return "value_" .. key
			end)

			local result = mockFunction.OnServerInvoke("MockPlayer", "GuardedInvoke", "score")
			check.equal(result, "blocked")
		end)
	end)

	test.suite("Network (Client Mode)", function()
		test.case("should initialize in client mode and expose client API", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = false,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local api = Network :: any
			check.not_nil(api.FireServer)
			check.not_nil(api.InvokeServer)
			-- Server-only methods should not exist
			check.equal(api.FireClient, nil)
			check.equal(api.FireAllClients, nil)
			check.equal(api.InvokeClient, nil)
		end)

		test.case("should dispatch events from server to client handler", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = false,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local receivedValue = nil
			Network.Register("ServerMessage", function(value)
				receivedValue = value
			end)

			-- Simulate server sending event to client
			mockEvent.OnClientEvent:Fire("ServerMessage", "hello")
			task.wait()

			check.equal(receivedValue, "hello")
		end)

		test.case("should fire events to server", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = false,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			local api = Network :: any
			api.FireServer("JumpEvent", 42)

			check.equal(#mockEvent._firedServer, 1)
		end)

		test.case("should apply client middleware to incoming events", function()
			local mockEvent = MockRemoteEvent.new()
			local mockFunction = MockRemoteFunction.new()

			Network._init({
				IsServer = false,
				EventDispatcher = mockEvent,
				UnreliableEventDispatcher = mockEvent,
				FunctionDispatcher = mockFunction,
			})

			Network.UseMiddleware("client", function(_funcName, next, value)
				return next(value .. "_processed")
			end)

			local received = nil
			Network.Register("FromServer", function(value)
				received = value
			end)

			mockEvent.OnClientEvent:Fire("FromServer", "payload")
			task.wait()

			check.equal(received, "payload_processed")
		end)
	end)
end
