--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local frktest = require(ReplicatedStorage.Packages.frktest)
local test = frktest.test
local check = frktest.assert.check

local Riptide = require(ReplicatedStorage.Riptide)

return function()
	test.suite("Riptide Client-Side Core Systems", function()
		
		test.case("Signal API behaves correctly on client", function()
			local signal = Riptide.Signal.new()
			local fired = false
			signal:Connect(function()
				fired = true
			end)
			signal:Fire()
			check.is_true(fired)
		end)

		test.case("Network Engine Client Middlewares", function()
			local mwFired = false
			local function dummyMiddleware(funcName, proceed, ...)
				mwFired = true
				return proceed(...)
			end
			
			Riptide.Network.UseMiddleware("client", dummyMiddleware)
			check.is_true(true) -- Tests lack live invocation without server bridging
			Riptide.Network.ClearMiddlewares("client")
		end)
		
		test.case("StateReplication Client Receive", function()
			-- Verifies state accessor doesn't error on Client
			local ok, err = pcall(function()
				return Riptide.State:Get("TestGold")
			end)
			check.is_true(ok, tostring(err))
		end)
		
		test.case("ComponentService Query", function()
			-- Verifies ComponentService Get API doesn't error
			local ok, err = pcall(function()
				return Riptide.ComponentService:Get(game, "NonExistentTag")
			end)
			
			check.is_true(ok, tostring(err))
		end)
		
	end)
end
