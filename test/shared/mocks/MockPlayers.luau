--!strict
-- Mock Players service for lifecycle testing
--!strict
local isRoblox = typeof(game) ~= "nil"
local task = task
if not isRoblox then
	pcall(function()
		task = require("@lune/task")
	end)
end
local Signal = isRoblox and require(game.ReplicatedStorage.Riptide.shared.Utilities.Signal)
	or require("../../../src/shared/Utilities/Signal")

local MockPlayers = {}
MockPlayers.__index = MockPlayers

function MockPlayers.new()
	local self = setmetatable({
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
		_players = {} :: { any },
	}, MockPlayers)

	return self
end

function MockPlayers:GetPlayers()
	return self._players
end

function MockPlayers:AddPlayer(player: any)
	table.insert(self._players, player)
	self.PlayerAdded:Fire(player)
end

function MockPlayers:RemovePlayer(player: any)
	for i, current in ipairs(self._players) do
		if current == player then
			table.remove(self._players, i)
			break
		end
	end
	self.PlayerRemoving:Fire(player)
end

return MockPlayers
