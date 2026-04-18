--!strict
local Network = require("../../src/shared/Network")
local ComponentService = require("../../src/shared/ComponentService")
local Signal = require("../../src/shared/Utilities/Signal")

-- Helper to format microsecond results
local function bench(name: string, iterations: number, fn: () -> ())
	local start = os.clock()
	for i = 1, iterations do
		fn()
	end
	local elapsed = os.clock() - start
	local timePerOpUs = (elapsed / iterations) * 1_000_000
	print(string.format("%-30s | %d iters | Total: %.3f ms | Per Op: %.4f µs", name, iterations, elapsed * 1000, timePerOpUs))
end

print("--- RIPTIDE COMPONENT BENCHMARKS ---")

-- 1. ComponentService:Get() Lookup Benchmark
local cs = ComponentService :: any
cs._isStarted = false
local mockInstance = { Name = "BenchPart" }
cs._registry = {}
cs._registry[mockInstance] = {}
cs._registry[mockInstance]["Hero"] = { name = "HeroComponent" }
cs._registry[mockInstance]["Health"] = { name = "HealthComponent" }

bench("ComponentService:Get (O(1))", 1_000_000, function()
	local _ = ComponentService:Get(mockInstance :: any, "Hero")
end)


-- 2. Signal Benchmark
local benchSig = Signal.new()
benchSig:Connect(function(val)
	local _ = val
end)

bench("Signal:Fire (1 connection)", 1_000_000, function()
	benchSig:Fire(100)
end)

local multipleSig = Signal.new()
for i = 1, 10 do
	multipleSig:Connect(function() end)
end
bench("Signal:Fire (10 connections)", 1_000_000, function()
	multipleSig:Fire()
end)

-- 3. Module Lookup Benchmark
local riptideMock = {
	_modules = { ["Economy/Bank"] = { balance = 100 } },
	_moduleAliases = { ["Bank"] = "Economy/Bank" },
}
function riptideMock:GetService(name)
	local module = self._modules[name]
	if module then return module end
	local alias = self._moduleAliases[name]
	if type(alias) == "string" then return self._modules[alias] end
end

bench("Riptide:GetService", 1_000_000, function()
	local _ = riptideMock:GetService("Bank")
end)
