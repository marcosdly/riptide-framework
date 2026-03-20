--!strict
return function()
	local Async = require(script.Parent.Async)

	describe("Async.Run", function()
		it("should run a synchronous function successfully", function()
			local result = Async.Run(function()
				return "success"
			end, 1, "timeout")

			expect(result).to.equal("success")
		end)

		it("should run an asynchronous function successfully", function()
			local result = Async.Run(function()
				task.wait(0.1)
				return "async success"
			end, 1, "timeout")

			expect(result).to.equal("async success")
		end)

		it("should timeout and return fallback value", function()
			local result = Async.Run(function()
				task.wait(0.5)
				return "too late"
			end, 0.1, "fallback")

			expect(result).to.equal("fallback")
		end)

		it("should handle multiple return values on success", function()
			local val1, val2 = Async.Run(function()
				return 1, 2
			end, 1, false, false)

			expect(val1).to.equal(1)
			expect(val2).to.equal(2)
		end)

		it("should handle multiple fallback return values on timeout", function()
			local val1, val2 = Async.Run(function()
				task.wait(0.5)
				return 99, 99
			end, 0.1, 1, 2)

			expect(val1).to.equal(1)
			expect(val2).to.equal(2)
		end)

		it("should catch and propagate errors from the underlying function", function()
			local success, result = pcall(function()
				Async.Run(function()
					error("internal error")
				end, 1)
			end)

			expect(success).to.equal(false)
			expect(string.find(tostring(result), "internal error") ~= nil).to.equal(true)
		end)
	end)

	describe("Async.Retry", function()
		it("should return on first successful attempt", function()
			local attempts = 0
			local result = Async.Retry(function()
				attempts += 1
				return "ok"
			end, 3)

			expect(result).to.equal("ok")
			expect(attempts).to.equal(1)
		end)

		it("should retry on failure and succeed eventually", function()
			local attempts = 0
			local result = Async.Retry(function()
				attempts += 1
				if attempts < 3 then
					error("not yet")
				end
				return "recovered"
			end, 5, 0)

			expect(result).to.equal("recovered")
			expect(attempts).to.equal(3)
		end)

		it("should throw after all attempts are exhausted", function()
			local attempts = 0
			local success, err = pcall(function()
				Async.Retry(function()
					attempts += 1
					error("always fails")
				end, 3, 0)
			end)

			expect(success).to.equal(false)
			expect(attempts).to.equal(3)
			expect(string.find(tostring(err), "always fails") ~= nil).to.equal(true)
		end)

		it("should pass arguments to the function on each attempt", function()
			local received = ""
			Async.Retry(function(a: string, b: string)
				received = a .. b
				return true
			end, 1, 0, "hello", "world")

			expect(received).to.equal("helloworld")
		end)

		it("should handle multiple return values", function()
			local a, b = Async.Retry(function()
				return 10, 20
			end, 1)

			expect(a).to.equal(10)
			expect(b).to.equal(20)
		end)
	end)

	describe("Async.Parallel", function()
		it("should run multiple functions and return all results", function()
			local results = Async.Parallel({
				function()
					return "a"
				end,
				function()
					return "b"
				end,
				function()
					return "c"
				end,
			})

			expect(results[1]).to.equal("a")
			expect(results[2]).to.equal("b")
			expect(results[3]).to.equal("c")
		end)

		it("should handle yielding functions", function()
			local results = Async.Parallel({
				function()
					task.wait(0.05)
					return 1
				end,
				function()
					task.wait(0.05)
					return 2
				end,
			}, 1)

			expect(results[1]).to.equal(1)
			expect(results[2]).to.equal(2)
		end)

		it("should return nil for failed tasks without crashing", function()
			local results = Async.Parallel({
				function()
					return "ok"
				end,
				function()
					error("boom")
				end,
				function()
					return "also ok"
				end,
			})

			-- Allow task.spawn error handlers to run
			task.wait()

			expect(results[1]).to.equal("ok")
			expect(results[2]).to.equal(nil)
			expect(results[3]).to.equal("also ok")
		end)

		it("should timeout and return partial results", function()
			local results = Async.Parallel({
				function()
					return "fast"
				end,
				function()
					task.wait(5)
					return "slow"
				end,
			}, 0.1)

			expect(results[1]).to.equal("fast")
			expect(results[2]).to.equal(nil) -- timed out
		end)
	end)
end
