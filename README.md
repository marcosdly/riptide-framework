<div align="center">

```text
    ____  _       __  _     __   
   / __ \(_)___  / /_(_)___/ /__ 
  / /_/ / / __ \/ __/ / __  / _ \
 / _, _/ / /_/ / /_/ / /_/ /  __/
/_/ |_/_/ .___/\__/_/\__,_/\___/ 
       /_/                       
```

[![Luau](https://img.shields.io/badge/Luau-00A2FF?style=flat-square&logo=lua&logoColor=white)](https://luau-lang.org/)
[![Roblox](https://img.shields.io/badge/Roblox-111111?style=flat-square&logo=roblox&logoColor=white)](https://roblox.com/)
[![Pesde](https://img.shields.io/badge/pesde-0.8.0-success?style=flat-square)](https://github.com/pesde-pkg)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![CI](https://github.com/riptide-project/framework/actions/workflows/ci.yml/badge.svg)](https://github.com/riptide-project/framework/actions/workflows/ci.yml)

**A lightweight, strictly-typed, and modular framework for Roblox.**

[Read the Documentation 📚](https://riptide-project.github.io/framework) • [Releases](https://github.com/riptide-project/framework/releases)

</div>

## 🌊 Why Riptide?

Riptide was built from the ground up for production Roblox games. It solves the most common architecture problems while remaining invisible, staying out of your way, and scaling elegantly.

- **Deterministic Lifecycle:** Phased initialization (`Init` → `Start`) eliminates race conditions.
- **Dependency Injection:** Ditch circular `require()` chains. Inject your dependencies safely using canonical paths.
- **Unified Networking:** One single `RemoteEvent` and `RemoteFunction` handle your entire game's network traffic. Zero `ReplicatedStorage` clutter. Let Riptide multiplex everything.
- **Strictly Typed:** 100% `--!strict` Luau. Enjoy flawless autocomplete and compile-time safety right out of the box.
- **Built-in Power:** Comes fully loaded with a robust `StateMachine`, `ComponentService`, and `StateReplication`.

## 📦 Installation

Riptide is distributed via **[Pesde](https://github.com/pesde-pkg/pesde)**. Install it directly into your project using the Pesde CLI:

```bash
pesde add riptide/core
```

## 🏁 Quick Look

Write clean, modular code with predictable execution phases.

```lua
--!strict
local RiptidePkg = require(ReplicatedStorage.Packages.Riptide)
type Riptide = RiptidePkg.Riptide

local PlayerState = {}

function PlayerState:Init(Riptide: Riptide)
    self.DataService = Riptide.GetService("DataService")
    
    Riptide.Network.Register("PlayerJumped", function(player, height)
        print(player.Name .. " jumped " .. height .. " studs!")
    end)
end

function PlayerState:Start(Riptide: Riptide)
    self.DataService:GiveMoney(100)
end

return PlayerState
```

## 📚 Documentation

For complete setup guides, API reference, and examples, visit our official documentation site:

**[👉 Go to Riptide Documentation](https://riptide-project.github.io/framework)**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.