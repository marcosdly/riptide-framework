---
title: Getting Started
description: A quick start guide to installing Riptide and writing your first service.
---

Welcome to Riptide! This guide will walk you through installing the framework, writing your first service, and launching your game.

## 1. Installation

### Via Pesde (Recommended)

Riptide is distributed via [pesde](https://github.com/pesde-pkg/pesde). To install it, run the following command in your terminal:

```bash
pesde add riptide/core
```

### Manual Installation

If you prefer not to use a package manager, download `Riptide.rbxm` from the [latest GitHub release](https://github.com/riptide-project/framework/releases/latest) and place it inside `ReplicatedStorage.Packages`.

### Riptide CLI (Under Development)

:::note
A dedicated `riptide` CLI tool is currently in active development. In the future, this CLI will automatically scaffold new projects, generate module files, and configure your sync tools with a single command. Until then, standard manual setup is required.
:::

---

## 2. Rojo Setup

If you are using Rojo to sync your code into Roblox Studio, here is the recommended `default.project.json` configuration. It properly routes your packages, server scripts, client scripts, and shared modules:

```json
{
  "name": "riptide-project",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Packages": {
        "$path": "roblox_packages"
      },
      "Shared": {
        "$path": "src/shared"
      }
    },
    "ServerScriptService": {
      "Server": {
        "$path": "src/server"
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": {
          "$path": "src/client"
        }
      }
    }
  }
}
```

---

## 3. Your First Service

In Riptide, game logic lives inside **modules** (Services on the server, Controllers on the client).

Let's create a simple Server service that prints a message when a player joins.

1. Create a `Folder` in `ServerScriptService` and name it `Services`.
2. Inside `Services`, create a `ModuleScript` named `HelloService`.
3. Paste the following code:

```lua
-- ServerScriptService/Services/HelloService.lua
local HelloService = {}

function HelloService:Init(Riptide)
    print("HelloService initialized!")
end

function HelloService:Start(Riptide)
    print("HelloService started!")
end

function HelloService:OnPlayerAdded(Riptide, player)
    print("Welcome to the game, " .. player.Name .. "!")
end

return HelloService
```

Riptide will automatically call `Init`, then `Start`, and trigger `OnPlayerAdded` whenever someone joins.

---

## 3. Launching the Framework

Riptide does **not** start automatically. You must explicitly tell it where your modules are and launch it from both the server and client.

### Server Entry Point

Create a standard `Script` inside `ServerScriptService` (e.g., `main.server.lua`):

```lua
-- ServerScriptService/main.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require the framework
local Riptide = require(ReplicatedStorage.Packages.Riptide)

-- Launch the server, supplying our Services folder
Riptide.Server.Launch({
    ModulesFolder = ServerScriptService.Services,
})
```

### Client Entry Point

Create a `LocalScript` inside `StarterPlayerScripts` (e.g., `main.client.lua`):

```lua
-- StarterPlayer.StarterPlayerScripts.main.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Riptide = require(ReplicatedStorage.Packages.Riptide)

-- We don't have Controllers yet, but we must launch the client anyway
Riptide.Client.Launch({
    ModulesFolder = Players.LocalPlayer.PlayerScripts,
})
```

---

## 4. Play the Game!

Press **Play** in Roblox Studio. In your Output window, you should see:

```
HelloService initialized!
HelloService started!
Welcome to the game, Player1!
```

Congratulations! You've successfully built your first Riptide project. 

## Next Steps

To learn more about how Riptide structures a full game, check out:
- **[Project Structure](../project-structure/)** — How to organize your folders.
- **[Module Lifecycle](../module-lifecycle/)** — How the Load/Init/Start cycle works in detail.
