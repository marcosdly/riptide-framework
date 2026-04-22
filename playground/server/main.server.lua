-- ServerScriptService/main.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("[main.server] Requiring Riptide...")
local Riptide = require(ReplicatedStorage.Packages.Riptide)
print("[main.server] Riptide loaded, launching Server.Launch...")

Riptide.Server.Launch({
	ModulesFolder = ServerScriptService.Services,
	SharedModulesFolder = ReplicatedStorage.SharedModules,
})

print("[main.server] Server.Launch() called, framework starting.")
