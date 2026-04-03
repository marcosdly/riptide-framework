--!strict
-- Riptide Test Runner
-- Runs all tests using frktest via Lune

local process = require("@lune/process")

local frktest = require("../luau_packages/frktest")
local console_reporter = require("../luau_packages/frktest").reporters.console_reporter

console_reporter.init()

-- Load all test suites
require("../test/lune/Signal.test")()
require("../test/lune/Async.test")()
require("../test/lune/Network.test")()
require("../test/lune/ComponentService.test")()
require("../test/lune/ModuleLoader.test")()
require("../test/lune/Riptide.test")()
require("../test/lune/StateReplication.test")()

local success = frktest.run()

-- Exit with non-zero code if any tests failed
if success then
	process.exit(0)
else
	process.exit(1)
end
