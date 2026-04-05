--!strict
-- PlayerLifecycle Test Suite (frktest)

local frktest = require("../../luau_packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local MockPlayers = require("./mocks/MockPlayers")
local PlayerLifecycle = require("../../src/shared/PlayerLifecycle")

return function()
	test.suite("PlayerLifecycle", function()
		test.case("should call player hooks for existing and joining players", function()
			local players = MockPlayers.new()
			local existing = { UserId = 1 }
			table.insert(players._players, existing)

			PlayerLifecycle:_init({
				Players = players,
			})

			local added = {}
			local loadedModules = {
				{
					name = "PlayerService",
					module = {
						OnPlayerAdded = function(_self: any, _riptide: any, player: any)
							table.insert(added, player)
						end,
					},
				},
			}

			PlayerLifecycle:Start(loadedModules, {})

			local joined = { UserId = 2 }
			players:AddPlayer(joined)

			check.equal(#added, 2)
			check.equal(added[1], existing)
			check.equal(added[2], joined)
		end)

		test.case("should cleanup state on player removing", function()
			local players = MockPlayers.new()
			local player = { UserId = 1 }
			table.insert(players._players, player)

			local removed = nil
			local state = {
				_onPlayerRemoving = function(_self: any, leavingPlayer: any)
					removed = leavingPlayer
				end,
			}

			PlayerLifecycle:_init({
				Players = players,
				StateReplication = state,
			})

			PlayerLifecycle:Start({}, {})
			players:RemovePlayer(player)

			check.equal(removed, player)
		end)
	end)
end
