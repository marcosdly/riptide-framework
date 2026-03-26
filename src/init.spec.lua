--!strict
return function()
	local RunService = game:GetService("RunService")
	local Riptide = require(script.Parent)
	local RiptideAny = Riptide :: any

	local function resetModuleRegistry()
		table.clear(RiptideAny._modules)
		table.clear(RiptideAny._moduleAliases)
	end

	describe("Riptide module lookup", function()
		beforeEach(function()
			resetModuleRegistry()
		end)

		it("should resolve both short alias and canonical path", function()
			local marker = { value = "ok" }
			RiptideAny._modules["Economy/PlayerData"] = marker
			RiptideAny._moduleAliases["PlayerData"] = "Economy/PlayerData"

			expect(Riptide.GetModule("PlayerData")).to.equal(marker)
			expect(Riptide.GetModule("Economy/PlayerData")).to.equal(marker)

			if RunService:IsServer() then
				expect(RiptideAny.GetService("PlayerData")).to.equal(marker)
			else
				expect(RiptideAny.GetController("PlayerData")).to.equal(marker)
			end
		end)

		it("should behave predictably for ambiguous short alias", function()
			local economyData = { domain = "economy" }
			local inventoryData = { domain = "inventory" }

			RiptideAny._modules["Economy/Data"] = economyData
			RiptideAny._modules["Inventory/Data"] = inventoryData
			RiptideAny._moduleAliases["Data"] = false

			expect(Riptide.GetModule("Data")).to.equal(nil)
			expect(Riptide.GetModule("Economy/Data")).to.equal(economyData)
			expect(Riptide.GetModule("Inventory/Data")).to.equal(inventoryData)
		end)
	end)
end
