--!strict
-- StateReplication Test Suite (frktest)

local Env = _G.TestEnv or require(script.Parent.TestEnv)
local task = Env.task

local frktest = Env.frktest
local test = frktest.test
local check = frktest.assert.check

local StateReplication = Env.RiptideShared.StateReplication

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

		test.case("should cleanup per-player state when player leaves", function()
			local network = createNetworkMock()
			local mockPlayer = { UserId = 1, Name = "Player1" }

			StateReplication:_init({
				IsServer = true,
				Network = network :: any,
			})

			StateReplication:Set("coins", 50)
			StateReplication:SetForPlayer(mockPlayer, "coins", 200)
			check.equal(StateReplication:Get("coins", mockPlayer), 200)

			StateReplication:_onPlayerRemoving(mockPlayer)
			check.equal(StateReplication:Get("coins", mockPlayer), 50)
		end)
	end)

	test.suite("StateReplication (Client)", function()
		test.case("should request snapshot and merge global + player state", function()
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
				scope = "global",
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

		test.case("should apply per-player delta even when global and player versions match", function()
			local network = createNetworkMock()
			network._snapshotResponse = {
				global = {
					coins = 0,
				},
				globalVersions = {
					coins = 1,
				},
				player = {
					coins = 100,
				},
				playerVersions = {
					coins = 1,
				},
			}

			StateReplication:_init({
				IsServer = false,
				Network = network :: any,
			})

			network.Trigger(StateReplication.Events.Delta, {
				scope = "global",
				key = "coins",
				value = 50,
				version = 2,
			})

			network.Trigger(StateReplication.Events.Delta, {
				scope = "player",
				key = "coins",
				value = 200,
				version = 2,
			})

			check.equal(StateReplication:Get("coins"), 200)
		end)

		test.case("should fall back to global value when player override is removed", function()
			local network = createNetworkMock()
			network._snapshotResponse = {
				global = {
					theme = "dark",
				},
				globalVersions = {
					theme = 1,
				},
				player = {
					theme = "custom",
				},
				playerVersions = {
					theme = 1,
				},
			}

			StateReplication:_init({
				IsServer = false,
				Network = network :: any,
			})

			network.Trigger(StateReplication.Events.Delta, {
				scope = "player",
				key = "theme",
				value = nil,
				version = 2,
			})

			check.equal(StateReplication:Get("theme"), "dark")
		end)

		test.case("should invoke initial subscribe callback synchronously", function()
			local network = createNetworkMock()
			network._snapshotResponse = {
				global = {
					coins = 77,
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

			local current = nil
			local unsubscribe = StateReplication:Subscribe("coins", function(value)
				current = value
			end)

			check.equal(current, 77)
			unsubscribe()
		end)

		test.case("should support legacy delta payload without scope", function()
			local network = createNetworkMock()
			network._snapshotResponse = {
				global = {
					coins = 10,
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

			network.Trigger(StateReplication.Events.Delta, {
				key = "coins",
				value = 25,
				version = 2,
			})

			check.equal(StateReplication:Get("coins"), 25)
		end)
	end)
end
