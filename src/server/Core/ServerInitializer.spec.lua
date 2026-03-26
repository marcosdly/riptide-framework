--!strict
return function()
	local ServerInitializer = require(script.Parent.ServerInitializer)
	local SignalModuleScript = script.Parent.Parent.Parent.shared.Utilities:WaitForChild("Signal") :: ModuleScript
	local AsyncModuleScript = script.Parent.Parent.Parent.shared.Utilities:WaitForChild("Async") :: ModuleScript

	describe("ServerInitializer", function()
		it("should load SharedModulesFolder and support multiple ModulesFolder entries", function()
			local originalRiptideRef = ServerInitializer._RiptideRef

			local mockRiptide = {
				_modules = {},
				_moduleAliases = {},
				ComponentService = {
					_start = function() end,
				},
			}

			ServerInitializer._RiptideRef = mockRiptide

			local sharedFolder = Instance.new("Folder")
			sharedFolder.Name = "SharedModules"

			local sharedEconomyFolder = Instance.new("Folder")
			sharedEconomyFolder.Name = "Economy"
			sharedEconomyFolder.Parent = sharedFolder

			local sharedPlayerDataModule = SignalModuleScript:Clone()
			sharedPlayerDataModule.Name = "PlayerData"
			sharedPlayerDataModule.Parent = sharedEconomyFolder

			local modulesFolderA = Instance.new("Folder")
			modulesFolderA.Name = "ServerModulesA"

			local economyFolder = Instance.new("Folder")
			economyFolder.Name = "Economy"
			economyFolder.Parent = modulesFolderA

			local economyDataModule = SignalModuleScript:Clone()
			economyDataModule.Name = "Data"
			economyDataModule.Parent = economyFolder

			local modulesFolderB = Instance.new("Folder")
			modulesFolderB.Name = "ServerModulesB"

			local inventoryFolder = Instance.new("Folder")
			inventoryFolder.Name = "Inventory"
			inventoryFolder.Parent = modulesFolderB

			local inventoryDataModule = AsyncModuleScript:Clone()
			inventoryDataModule.Name = "Data"
			inventoryDataModule.Parent = inventoryFolder

			ServerInitializer.Launch({
				ModulesFolder = { modulesFolderA, modulesFolderB },
				SharedModulesFolder = { sharedFolder },
			})

			expect((mockRiptide :: any)._modules["Economy/PlayerData"]).to.be.ok()
			expect((mockRiptide :: any)._modules["Economy/Data"]).to.be.ok()
			expect((mockRiptide :: any)._modules["Inventory/Data"]).to.be.ok()
			expect((mockRiptide :: any)._moduleAliases["Data"]).to.equal(false)

			ServerInitializer._RiptideRef = originalRiptideRef
		end)
	end)
end
