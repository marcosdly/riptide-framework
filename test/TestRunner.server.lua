-- TestEZ Runner
-- Automatically discovers and runs all .spec.lua files in the Riptide package

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

TestEZ.TestBootstrap:run({
	ReplicatedStorage.Riptide,
})
