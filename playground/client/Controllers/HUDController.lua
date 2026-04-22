--!strict
-- StarterPlayer/StarterPlayerScripts/Controllers/HUDController.lua
-- Test client controller

local HUDController = {}

HUDController._unsubscribeCoins = nil :: (() -> ())?
HUDController._unsubscribePhase = nil :: (() -> ())?

--------------------------------------------------------------
-- INIT
--------------------------------------------------------------
function HUDController:Init(Riptide)
	print("[HUDController] ▶ Init called")

	self.Network = Riptide.Network
	self.State = Riptide.State

	local SharedConfig = Riptide.GetModule("SharedConfig")
	if SharedConfig then
		print("[HUDController]   SharedConfig.GAME_NAME =", SharedConfig.GAME_NAME)
	else
		print("[HUDController]   ⚠️ SharedConfig NOT FOUND")
	end

	Riptide.Network.Register("CoinSpent", function(newBalance)
		print("[HUDController] Network event 'CoinSpent' received, balance:", newBalance)
	end)

	Riptide.Network.Register("PlayerJoined", function(playerName)
		print("[HUDController] Network event 'PlayerJoined':", playerName, "joined!")
	end)

	print("[HUDController] ✅ Init completed")
end

--------------------------------------------------------------
-- START
--------------------------------------------------------------
function HUDController:Start(Riptide)
	print("[HUDController] ▶ Start called")

	self._unsubscribeCoins = Riptide.State:Subscribe("coins", function(value)
		print("[HUDController] State:Subscribe('coins') → value =", value)
	end)

	self._unsubscribePhase = Riptide.State:Subscribe("matchPhase", function(value)
		print("[HUDController] State:Subscribe('matchPhase') → value =", value)
	end)

	task.delay(2, function()
		print("[HUDController] Calling InvokeServer('GetCoins')...")
		local coins = Riptide.Network.InvokeServer("GetCoins")
		print("[HUDController]   InvokeServer returned:", coins)
	end)

	task.delay(4, function()
		print("[HUDController] Calling FireServer('SpendCoins', 25)...")
		Riptide.Network.FireServer("SpendCoins", 25)
	end)

	-- Signal utility test
	local testSignal = Riptide.Signal.new()
	local conn = testSignal:Connect(function(msg)
		print("[HUDController] Signal test — received:", msg)
	end)
	testSignal:Fire("Hello from Signal!")
	conn:Disconnect()
	print("[HUDController]   Signal test — connection.Connected =", conn.Connected)
	testSignal:Destroy()

	print("[HUDController] ✅ Start completed")
end

return HUDController
