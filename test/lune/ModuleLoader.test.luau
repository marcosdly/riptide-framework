--!strict
-- ModuleLoader Test Suite (frktest)
-- Tests the shared module loading logic extracted from Initializers.

local frktest = require("../../luau_packages/frktest")
local test = frktest.test
local check = frktest.assert.check

local ModuleLoader = require("../../src/shared/ModuleLoader")

return function()
	test.suite("ModuleLoader.GetCanonicalModuleId", function()
		-- We use plain table mocks since Lune does not have Roblox Instance hierarchy.
		-- GetCanonicalModuleId walks .Parent up to the folder, so we mock that chain.

		test.case("should return short name when module is direct child", function()
			local folder = { Name = "Modules" }
			local moduleScript = { Name = "PlayerService", Parent = folder }
			-- Since our mock doesn't use IsA/GetFullName, we test the path logic directly
			-- The function walks Parent until it finds modulesFolder.
			-- With mock: moduleScript.Parent == folder, so it returns "PlayerService"
			local id = ModuleLoader.GetCanonicalModuleId(folder :: any, moduleScript :: any)
			check.equal(id, "PlayerService")
		end)

		test.case("should return nested path for sub-folder modules", function()
			local folder = { Name = "Modules" }
			local subFolder = { Name = "Economy", Parent = folder }
			local moduleScript = { Name = "PlayerData", Parent = subFolder }

			local id = ModuleLoader.GetCanonicalModuleId(folder :: any, moduleScript :: any)
			check.equal(id, "Economy/PlayerData")
		end)

		test.case("should return short name when parent chain does not reach folder", function()
			local folder = { Name = "Modules" }
			local otherParent = { Name = "Other", Parent = nil }
			local moduleScript = { Name = "Orphan", Parent = otherParent }

			local id = ModuleLoader.GetCanonicalModuleId(folder :: any, moduleScript :: any)
			check.equal(id, "Orphan")
		end)
	end)

	test.suite("ModuleLoader.NormalizeFolders", function()
		test.case("should return empty table for nil input", function()
			local result = ModuleLoader.NormalizeFolders(nil, "TestField")
			check.equal(#result, 0)
		end)

		test.case("should error for non-Folder input", function()
			local ok = pcall(function()
				ModuleLoader.NormalizeFolders("not a folder" :: any, "TestField")
			end)
			check.equal(ok, false)
		end)
	end)
end
