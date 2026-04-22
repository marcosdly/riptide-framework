--!strict
-- ServerScriptService/Services/CoinService.lua
-- Test service: coins, state, network, state machine, lifecycle hooks

local CoinService = {}

CoinService._matchFSM = nil :: any

--------------------------------------------------------------
-- INIT
--------------------------------------------------------------
function CoinService:Init(Riptide)
	print("[CoinService] ▶ Init called")

	self.State = Riptide.State
	self.Network = Riptide.Network

	Riptide.Network.Register("GetCoins", function(player)
		print("[CoinService] Network.Register('GetCoins') called by player:", player.Name)
		local coins = self.State:Get("coins", player)
		print("[CoinService]   Returning coins =", coins)
		return coins
	end)

	Riptide.Network.Register("SpendCoins", function(player, amount)
		print("[CoinService] Network.Register('SpendCoins') called:", player.Name, "amount=", amount)
		local newCoins = self.State:UpdateForPlayer(player, "coins", function(old)
			return math.max(0, (old or 0) - (amount or 0))
		end)
		print("[CoinService]   New balance:", newCoins)

		Riptide.Network.FireClient(player, "CoinSpent", newCoins)
		print("[CoinService]   FireClient('CoinSpent') sent")
	end)

	print("[CoinService] ✅ Init completed")
end

--------------------------------------------------------------
-- START
--------------------------------------------------------------
function CoinService:Start(Riptide)
	print("[CoinService] ▶ Start called")

	self._matchFSM = Riptide.StateMachine.new({
		InitialState = "Lobby",
		States = {
			Lobby = {
				OnEnter = function(self)
					print("[CoinService/FSM] Entered state: Lobby")
				end,
				OnExit = function(self)
					print("[CoinService/FSM] Exiting state: Lobby")
				end,
			},
			Playing = {
				OnEnter = function(self)
					print("[CoinService/FSM] Entered state: Playing")
				end,
				OnUpdate = function(self, dt) end,
				OnExit = function(self)
					print("[CoinService/FSM] Exiting state: Playing")
				end,
			},
			GameOver = {
				OnEnter = function(self, reason)
					print("[CoinService/FSM] Entered state: GameOver, reason:", reason)
				end,
			},
		},
	})

	self._matchFSM.OnStateChanged:Connect(function(oldState, newState)
		print("[CoinService/FSM] OnStateChanged:", oldState, "→", newState)
		Riptide.State:Set("matchPhase", newState)
		print("[CoinService] State:Set('matchPhase',", newState, ")")
	end)

	Riptide.State:Set("matchPhase", "Lobby")
	print("[CoinService] Initial State:Set('matchPhase', 'Lobby')")

	task.delay(5, function()
		print("[CoinService] task.delay(5) — transition to Playing")
		self._matchFSM:TransitionTo("Playing")
	end)

	task.delay(15, function()
		print("[CoinService] task.delay(15) — transition to GameOver")
		self._matchFSM:TransitionTo("GameOver", "Timeout")
	end)

	print("[CoinService] ✅ Start completed")
end

--------------------------------------------------------------
-- PLAYER LIFECYCLE HOOKS
--------------------------------------------------------------
function CoinService:OnPlayerAdded(Riptide, player)
	print("[CoinService] ▶ OnPlayerAdded:", player.Name)

	Riptide.State:SetForPlayer(player, "coins", 100)
	print("[CoinService]   SetForPlayer coins = 100")

	Riptide.Network.FireAllClients("PlayerJoined", player.Name)
	print("[CoinService]   FireAllClients('PlayerJoined',", player.Name, ")")
end

function CoinService:OnPlayerRemoving(Riptide, player)
	print("[CoinService] ▶ OnPlayerRemoving:", player.Name)

	local finalCoins = Riptide.State:Get("coins", player)
	print("[CoinService]   Final balance:", finalCoins)
end

return CoinService
