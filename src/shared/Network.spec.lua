--!strict
return function()
	local RunService = game:GetService("RunService")
	local Network = require(script.Parent.Network)

	local IS_SERVER = RunService:IsServer()

	describe("Network", function()
		it("should properly register and unregister event handlers", function()
			local function testHandler() end

			expect(function()
				Network.Register("SharedTestEvent", testHandler)
			end).never.to.throw()

			expect(function()
				Network.Unregister("SharedTestEvent", testHandler)
			end).never.to.throw()
		end)

		it("should clean up empty handler entries after unregister", function()
			local function handler() end

			Network.Register("CleanupTest", handler)
			Network.Unregister("CleanupTest", handler)

			-- Re-register to verify no stale state issues
			expect(function()
				Network.Register("CleanupTest", handler)
				Network.Unregister("CleanupTest", handler)
			end).never.to.throw()
		end)

		if IS_SERVER then
			it("should expose Server -> Client API on server", function()
				local api = Network :: any
				expect(type(api.FireClient)).to.equal("function")
				expect(type(api.FireAllClients)).to.equal("function")
				expect(type(api.InvokeClient)).to.equal("function")
			end)

			it("should not expose Client -> Server API on server", function()
				local api = Network :: any
				expect(api.FireServer).to.equal(nil)
				expect(api.InvokeServer).to.equal(nil)
			end)
		else
			it("should expose Client -> Server API on client", function()
				expect(function()
					Network.FireServer("ClientTestEvent", 1, 2, 3)
				end).never.to.throw()
			end)

			it("should not expose Server -> Client API on client", function()
				local api = Network :: any
				expect(api.FireClient).to.equal(nil)
				expect(api.FireAllClients).to.equal(nil)
				expect(api.InvokeClient).to.equal(nil)
			end)
		end
	end)
end
