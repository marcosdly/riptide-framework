---
title: Getting Started
description: A quick start guide to installing Riptide and writing your first service.
---

Welcome to Riptide! This guide will walk you through installing the framework, writing your first service, and launching your game.

## 1. Installation

### Via Pesde (Recommended)

Riptide is formally distributed via [pesde](https://github.com/pesde-pkg/pesde). To install it, run the following command in your terminal:

```bash
pesde add riptide/core
```

### Via Wally

:::caution[Wally Scope Pending]
The `riptide` Wally scope is currently awaiting registry synchronization. For immediate installation, please use **Pesde** or the manual `.rbxm` download below.
:::

If you strictly prefer Wally, add this to your `wally.toml`:

```toml
[dependencies]
Riptide = "riptide/core@0.8.2"
```

### Manual Installation (.rbxm)

If you prefer not to use a package manager, download `Riptide.rbxm` from the [latest GitHub release](https://github.com/riptide-project/framework/releases/latest) and explicitly place it inside `ReplicatedStorage.Packages`.

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
      "SharedModules": {
        "$path": "src/shared"
      }
    },
    "ServerScriptService": {
      "main": {
        "$path": "src/server/main.server.lua"
      },
      "Services": {
        "$path": "src/server/Services"
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "main": {
          "$path": "src/client/main.client.lua"
        },
        "Controllers": {
          "$path": "src/client/Controllers"
        }
      }
    }
  }
}
```

This produces the following hierarchy inside Roblox Studio:

```
ServerScriptService/
├── main                    (Script)
└── Services/               (Folder)

StarterPlayer/StarterPlayerScripts/
├── main                    (LocalScript)
└── Controllers/            (Folder)

ReplicatedStorage/
├── Packages/               (installed dependencies)
└── SharedModules/          (shared code)
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

-- The `:` colon syntax means `self` (HelloService table) is the implicit first argument.
-- `Riptide` is the framework reference passed as the second argument.
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

Riptide will automatically call `Init` (synchronously), then `Start` (via `task.spawn`). The `OnPlayerAdded` hook fires whenever a player joins the server.

:::note
Inside `OnPlayerAdded`, always use the `Riptide` argument (not `self.State` or other fields set during `Init`) to access framework APIs. See [Player Lifecycle](../../api/player-lifecycle/) for details.
:::

---

## 4. Launching the Framework

Riptide does **not** start automatically. You must explicitly tell it where your modules are and launch it from both the server and client.

### Server Entry Point

Create a standard `Script` inside `ServerScriptService` (e.g., `main.server.lua`):

```lua
-- ServerScriptService/main.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Riptide = require(ReplicatedStorage.Packages.Riptide)

Riptide.Server.Launch({
    ModulesFolder = ServerScriptService.Services,
    SharedModulesFolder = ReplicatedStorage.SharedModules, -- optional
})
```

### Client Entry Point

Create a `LocalScript` inside `StarterPlayerScripts` (e.g., `main.client.lua`):

```lua
-- StarterPlayer/StarterPlayerScripts/main.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Riptide = require(ReplicatedStorage.Packages.Riptide)

Riptide.Client.Launch({
    ModulesFolder = Players.LocalPlayer.PlayerScripts.Controllers,
    SharedModulesFolder = ReplicatedStorage.SharedModules, -- optional
})
```

:::tip
`SharedModulesFolder` is optional. If provided, shared modules are loaded **before** side-specific modules, so services and controllers can depend on shared code during `Init`. See [Project Structure](../project-structure/) for details.
:::

---

## 5. Play the Game!

Press **Play** in Roblox Studio. In your Output window, you should see:

```
🌊 [Riptide] Server Initialization Started...
HelloService initialized!
HelloService started!
🌊 [Riptide] ✅ Server Start Phase Dispatched.
Welcome to the game, Player1!
```

Congratulations! You've successfully built your first Riptide project.

## Next Steps

To learn more about how Riptide structures a full game, check out:
- **[Project Structure](../project-structure/)** — How to organize your folders.
- **[Module Lifecycle](../module-lifecycle/)** — How the Load/Init/Start cycle works in detail.
