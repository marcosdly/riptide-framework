--!strict
-- StateReplication Test Suite (frktest)

local frktest = require("../../luau_packages/frktest")
local task = require("@lune/task")
local test = frktest.test
local check = frktest.assert.check

local StateReplication = require("../../src/shared/StateReplication")

local function createNetworkMock()
	local handlers = {} :: { [string]: { (...any) -> any } }

	local network = {
		_firedAll = {} :: { any },
		_firedClient = {} :: { any },
		_snapshotResponse = nil :: any,
	}

	function network.Register(name: string, callback: (...any) -> any)
		if not handlers[name] then
			handlers[name] = {}
		end
		table.insert(handlers[name], callback)
	end

	function network.Unregister(name: string, callback: (...any) -> any)
		local list = handlers[name]
		if not list then
			return
		end

		for i, current in ipairs(list) do
			if current == callback then
				table.remove(list, i)
				break
			end
		end

		if #list == 0 then
			handlers[name] = nil
		end
	end

	function network.FireAllClients(name: string, payload: any)
		table.insert(network._firedAll, {
			name = name,
			payload = payload,
		})
	end

	function network.FireClient(player: any, name: string, payload: any)
		table.insert(network._firedClient, {
			player = player,
			name = name,
			payload = payload,
		})
	end

	function network.InvokeServer(name: string): any
		if name == StateReplication.Events.Snapshot then
			return network._snapshotResponse
		end
		return nil
	end

	function network.Trigger(name: string, ...: any)
		local list = handlers[name]
		if not list then
			return
		end
		for _, callback in ipairs(list) do
			callback(...)
		end
	end

	return network
end

return function()
	test.suite("StateReplication (Server)", function()
		test.case("should set global state and broadcast delta", function()
			StateReplication:_resetForTests()
			local network = createNetworkMock()

			StateReplication:_init({
				IsServer = true,
				Network = network :: any,
			})

			StateReplication:Set("dayCycle", "night")

			check.equal(StateReplication:Get("dayCycle"), "night")
			check.equal(#network._firedAll, 1)
			check.equal(network._firedAll[1].name, StateReplication.Events.Delta)
			check.equal(network._firedAll[1].payload.key, "dayCycle")
			check.equal(network._firedAll[1].payload.value, "night")
		end)

		test.case("should set per-player state and only target that player", function()
			StateReplication:_resetForTests()
			local network = createNetworkMock()
			local mockPlayer = { UserId = 1, Name = "Player1" }

			StateReplication:_init({
				IsServer = true,
				Network = network :: any,
			})

			StateReplication:SetForPlayer(mockPlayer, "coins", 125)

			check.equal(StateReplication:Get("coins", mockPlayer), 125)
			check.equal(#network._firedClient, 1)
			check.equal(network._firedClient[1].player, mockPlayer)
			check.equal(network._firedClient[1].name, StateReplication.Events.Delta)
			check.equal(network._firedClient[1].payload.key, "coins")
			check.equal(network._firedClient[1].payload.value, 125)
			check.equal(#network._firedAll, 0)
		end)

		test.case("should update per-player state via callback", function()
			StateReplication:_resetForTests()
			local network = createNetworkMock()
			local mockPlayer = { UserId = 1, Name = "Player1" }

			StateReplication:_init({
				IsServer = true,
				Network = network :: any,
			})

			StateReplication:SetForPlayer(mockPlayer, "coins", 100)
			local result = StateReplication:UpdateForPlayer(mockPlayer, "coins", function(oldValue)
				return (oldValue or 0) + 10
			end)

			check.equal(result, 110)
			check.equal(StateReplication:Get("coins", mockPlayer), 110)
			check.equal(#network._firedClient, 2)
			check.equal(network._firedClient[2].payload.value, 110)
		end)
	end)

	test.suite("StateReplication (Client)", function()
		test.case("should request snapshot and merge global + player state", function()
			StateReplication:_resetForTests()
			local network = createNetworkMock()
			network._snapshotResponse = {
				global = {
					dayCycle = "day",
					coins = 10,
				},
				globalVersions = {
					dayCycle = 1,
					coins = 1,
				},
				player = {
					coins = 250,
				},
				playerVersions = {
					coins = 5,
				},
			}

			StateReplication:_init({
				IsServer = false,
				Network = network :: any,
			})

			check.equal(StateReplication:Get("dayCycle"), "day")
			check.equal(StateReplication:Get("coins"), 250)
		end)

		test.case("should notify subscribers on delta updates", function()
			StateReplication:_resetForTests()
			local network = createNetworkMock()
			network._snapshotResponse = {
				global = {
					coins = 100,
				},
				globalVersions = {
					coins = 1,
				},
				player = {},
				playerVersions = {},
			}

			StateReplication:_init({
				IsServer = false,
				Network = network :: any,
			})

			local updates = {}
			local unsubscribe = StateReplication:Subscribe("coins", function(value)
				table.insert(updates, value)
			end)

			network.Trigger(StateReplication.Events.Delta, {
				key = "coins",
				value = 500,
				version = 2,
			})
			task.wait()

			check.equal(StateReplication:Get("coins"), 500)
			check.equal(updates[1], 100)
			check.equal(updates[2], 500)

			unsubscribe()
		end)
	end)
end
