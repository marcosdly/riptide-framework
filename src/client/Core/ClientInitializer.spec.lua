--!strict
return function()
	local ClientInitializer = require(script.Parent.ClientInitializer)
	local SignalModuleScript = script.Parent.Parent.Parent.shared.Utilities:WaitForChild("Signal") :: ModuleScript
	local AsyncModuleScript = script.Parent.Parent.Parent.shared.Utilities:WaitForChild("Async") :: ModuleScript

	describe("ClientInitializer", function()
		it("should load SharedModulesFolder and support multiple ModulesFolder entries", function()
			local originalRiptideRef = ClientInitializer._RiptideRef

			local mockRiptide = {
				_modules = {},
				_moduleAliases = {},
				ComponentService = {
					_start = function() end,
				},
			}

			ClientInitializer._RiptideRef = mockRiptide

			local sharedFolder = Instance.new("Folder")
			sharedFolder.Name = "SharedModules"

			local sharedEconomyFolder = Instance.new("Folder")
			sharedEconomyFolder.Name = "Economy"
			sharedEconomyFolder.Parent = sharedFolder

			local sharedPlayerDataModule = SignalModuleScript:Clone()
			sharedPlayerDataModule.Name = "PlayerData"
			sharedPlayerDataModule.Parent = sharedEconomyFolder

			local modulesFolderA = Instance.new("Folder")
			modulesFolderA.Name = "ClientModulesA"

			local economyFolder = Instance.new("Folder")
			economyFolder.Name = "Economy"
			economyFolder.Parent = modulesFolderA

			local economyDataModule = SignalModuleScript:Clone()
			economyDataModule.Name = "Data"
			economyDataModule.Parent = economyFolder

			local modulesFolderB = Instance.new("Folder")
			modulesFolderB.Name = "ClientModulesB"

			local inventoryFolder = Instance.new("Folder")
			inventoryFolder.Name = "Inventory"
			inventoryFolder.Parent = modulesFolderB

			local inventoryDataModule = AsyncModuleScript:Clone()
			inventoryDataModule.Name = "Data"
			inventoryDataModule.Parent = inventoryFolder

			ClientInitializer.Launch({
				ModulesFolder = { modulesFolderA, modulesFolderB },
				SharedModulesFolder = { sharedFolder },
			})

			expect((mockRiptide :: any)._modules["Economy/PlayerData"]).to.be.ok()
			expect((mockRiptide :: any)._modules["Economy/Data"]).to.be.ok()
			expect((mockRiptide :: any)._modules["Inventory/Data"]).to.be.ok()
			expect((mockRiptide :: any)._moduleAliases["Data"]).to.equal(false)

			ClientInitializer._RiptideRef = originalRiptideRef
		end)
	end)
end
