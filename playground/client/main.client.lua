-- StarterPlayer/StarterPlayerScripts/main.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("[main.client] Requiring Riptide...")
local Riptide = require(ReplicatedStorage.Packages.Riptide)
print("[main.client] Riptide loaded, launching Client.Launch...")

Riptide.Client.Launch({
	ModulesFolder = Players.LocalPlayer.PlayerScripts.Controllers,
	SharedModulesFolder = ReplicatedStorage.SharedModules,
})

print("[main.client] Client.Launch() called, framework starting.")
