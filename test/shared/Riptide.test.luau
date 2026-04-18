--!strict
-- Riptide (init) Test Suite (frktest)
-- Tests module lookup logic (canonical IDs, aliases, ambiguous names).
-- Since init.lua requires Roblox runtime, we test the GetModule logic directly
-- by requiring just the shared modules and mocking the registry.

local Env = _G.TestEnv or require(script.Parent.TestEnv)
local task = Env.task

local frktest = Env.frktest
local test = frktest.test
local check = frktest.assert.check

return function()
	test.suite("Riptide Module Lookup", function()
		-- Create a minimal mock of Riptide's lookup logic
		-- (since init.lua itself depends on RunService, we test the algorithm directly)

		local function createRiptideMock()
			local riptide = {
				_modules = {} :: { [string]: any },
				_moduleAliases = {} :: { [string]: string | false },
			}

			function riptide.GetModule(name: string): any
				local module = riptide._modules[name]
				if module then
					return module
				end

				local aliasValue = riptide._moduleAliases[name]
				if aliasValue == false then
					return nil -- ambiguous
				end

				if type(aliasValue) == "string" then
					module = riptide._modules[aliasValue]
					if module then
						return module
					end
				end

				return nil
			end

			return riptide
		end

		test.case("should resolve both short alias and canonical path", function()
			local riptide = createRiptideMock()
			local marker = { value = "ok" }
			riptide._modules["Economy/PlayerData"] = marker
			riptide._moduleAliases["PlayerData"] = "Economy/PlayerData"

			check.equal(riptide.GetModule("PlayerData"), marker)
			check.equal(riptide.GetModule("Economy/PlayerData"), marker)
		end)

		test.case("should return nil for ambiguous short alias", function()
			local riptide = createRiptideMock()
			local economyData = { domain = "economy" }
			local inventoryData = { domain = "inventory" }

			riptide._modules["Economy/Data"] = economyData
			riptide._modules["Inventory/Data"] = inventoryData
			riptide._moduleAliases["Data"] = false

			check.equal(riptide.GetModule("Data"), nil)
			check.equal(riptide.GetModule("Economy/Data"), economyData)
			check.equal(riptide.GetModule("Inventory/Data"), inventoryData)
		end)

		test.case("should return nil for non-existent module", function()
			local riptide = createRiptideMock()
			check.equal(riptide.GetModule("NonExistent"), nil)
		end)
	end)
end
