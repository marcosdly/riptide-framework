--!strict
local frktest = require("../../luau_packages/frktest")
local console_reporter = frktest.reporters.console_reporter

console_reporter.init()

print("LOADING CHAOS TEST SUITE...")
require("./Chaos.test")()
print("LOADED CHAOS TEST SUITE. RUNNING...")

local success = frktest.run()
print("FINISHED RUNNING. SUCCESS: ", success)
