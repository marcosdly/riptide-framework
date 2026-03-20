--!strict
return function()
	local Signal = require(script.Parent.Signal)

	describe("Signal", function()
		it("should create a new signal", function()
			local sig = Signal.new()
			expect(sig).to.be.ok()
			expect(sig._head).to.equal(nil)
		end)

		it("should connect to a function and fire", function()
			local sig = Signal.new()
			local fired = false
			local value = 0

			local conn = sig:Connect(function(v)
				fired = true
				value = v
			end)

			expect(conn).to.be.ok()
			expect(conn.Connected).to.equal(true)
			expect(sig._head).to.equal(conn)

			sig:Fire(42)
			task.wait() -- Allow task.spawn to execute

			expect(fired).to.equal(true)
			expect(value).to.equal(42)
		end)

		it("should disconnect correctly and clear references", function()
			local sig = Signal.new()
			local count = 0

			local conn = sig:Connect(function()
				count += 1
			end)

			sig:Fire()
			task.wait()
			expect(count).to.equal(1)

			conn:Disconnect()
			expect(conn.Connected).to.equal(false)
			expect(sig._head).to.equal(nil)

			-- Verify references are cleared (memory leak prevention)
			expect((conn :: any)._signal).to.equal(nil)
			expect((conn :: any)._fn).to.equal(nil)
			expect((conn :: any)._next).to.equal(nil)

			sig:Fire()
			task.wait()
			expect(count).to.equal(1) -- Should not trigger again
		end)

		it("should support Once (auto-disconnect after first fire)", function()
			local sig = Signal.new()
			local count = 0

			local conn = sig:Once(function()
				count += 1
			end)

			expect(conn.Connected).to.equal(true)

			sig:Fire()
			task.wait()
			expect(count).to.equal(1)
			expect(conn.Connected).to.equal(false)

			-- Second fire should not trigger
			sig:Fire()
			task.wait()
			expect(count).to.equal(1)
		end)

		it("should wait and yield correctly", function()
			local sig = Signal.new()
			local value1, value2

			task.spawn(function()
				value1, value2 = sig:Wait()
			end)

			-- Check that there's a temporary connection
			expect(sig._head).to.be.ok()

			sig:Fire("Hello", "World")
			task.wait()

			expect(value1).to.equal("Hello")
			expect(value2).to.equal("World")

			-- Memory leak check: the connection must be cleaned automatically
			expect(sig._head).to.equal(nil)
		end)

		it("should disconnect all connections and clear references", function()
			local sig = Signal.new()
			local count1 = 0
			local count2 = 0

			local conn1 = sig:Connect(function()
				count1 += 1
			end)

			local conn2 = sig:Connect(function()
				count2 += 1
			end)

			expect(sig._head).to.be.ok()
			expect(conn1.Connected).to.equal(true)
			expect(conn2.Connected).to.equal(true)

			sig:DisconnectAll()

			expect(sig._head).to.equal(nil)
			expect(conn1.Connected).to.equal(false)
			expect(conn2.Connected).to.equal(false)

			-- Verify references are fully cleared
			expect((conn1 :: any)._fn).to.equal(nil)
			expect((conn2 :: any)._fn).to.equal(nil)

			sig:Fire()
			task.wait()

			expect(count1).to.equal(0)
			expect(count2).to.equal(0)
		end)

		it("should support Destroy and prevent further use", function()
			local sig = Signal.new()

			local conn = sig:Connect(function() end)
			expect(conn.Connected).to.equal(true)

			sig:Destroy()

			expect(conn.Connected).to.equal(false)
			expect(sig._head).to.equal(nil)
		end)
	end)
end
