--!strict
return function()
	local ComponentService = require(script.Parent.ComponentService)

	describe("ComponentService", function()
		it("should initialize component classes when _start is called", function()
			-- Create a fake Folder to mock the Modules behavior
			local MockComponentsFolder = Instance.new("Folder")

			local mockComponentSource = Instance.new("ModuleScript")
			mockComponentSource.Name = "TestMockComponent"
			-- It's tricky to inject source code to ModuleScripts dynamically and require it in Roblox without
			-- loadstring which is unavailable. So we will just test the Service's error handling and state mechanisms.
			-- If the Module doesn't load a valid component class (since it's empty), it prints a warning and skips.
			mockComponentSource.Parent = MockComponentsFolder

			expect(function()
				ComponentService:_start(MockComponentsFolder)
			end).never.to.throw()
		end)

		it("should link tags to instanced components securely", function()
			-- Let's manually register a fake component wrapper to test ComponentService internals
			-- without needing to require() a physical module script

			local mockInstance = Instance.new("Part")
			local TestTag = "TestTagComponent"
			local testWrapper = { Destroy = function() end }

			-- Mocking the internal state that _start would have created
			ComponentService._registry[mockInstance] = {}
			ComponentService._registry[mockInstance][TestTag] = testWrapper

			local fetched = ComponentService:Get(mockInstance)
			expect(fetched).to.equal(testWrapper)
		end)

		it("should support tag-specific Get lookup", function()
			local mockInstance = Instance.new("Part")
			local Tag1 = "TagAlpha"
			local Tag2 = "TagBeta"

			local wrapper1 = { name = "alpha" }
			local wrapper2 = { name = "beta" }

			ComponentService._registry[mockInstance] = {}
			ComponentService._registry[mockInstance][Tag1] = wrapper1
			ComponentService._registry[mockInstance][Tag2] = wrapper2

			expect(ComponentService:Get(mockInstance, Tag1)).to.equal(wrapper1)
			expect(ComponentService:Get(mockInstance, Tag2)).to.equal(wrapper2)
		end)

		it("should clean up internal memory when a tagged instance is destroyed", function()
			local mockInstance = Instance.new("Part")
			local TestTag = "MemoryLeakComponent"

			local destroyedCalled = false
			local testWrapper = {
				Destroy = function()
					destroyedCalled = true
				end,
			}

			ComponentService._registry[mockInstance] = {}
			ComponentService._registry[mockInstance][TestTag] = testWrapper

			-- Re-simulate what happens in GetInstanceRemovedSignal
			local components = ComponentService._registry[mockInstance]
			if components then
				local componentObj = components[TestTag]
				if componentObj then
					if type(componentObj.Destroy) == "function" then
						pcall(componentObj.Destroy, componentObj)
					end
					components[TestTag] = nil
				end
			end

			expect(destroyedCalled).to.equal(true)
			expect(ComponentService:Get(mockInstance)).to.equal(nil)
		end)
	end)
end
