# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Planned]

### Added
- State machine module (workflow/state orchestration) for gameplay and service-level flows.

## [0.7.0] - 2026-04-03

### Added
- `StateReplication` module (`Riptide.State`) with server-authoritative global and per-player state sync.
- `State:UpdateForPlayer(player, key, updater)` for atomic callback-based per-player state updates.
- Client subscriptions for state keys via `State:Subscribe(key, callback)` with immediate callback and unsubscribe handle.
- Automatic client snapshot sync (`State:RequestSync()`) plus delta updates over the unified network layer.
- Public `Riptide.State` API exposed from framework entrypoint.
- New test suite for StateReplication (`test/lune/StateReplication.test.luau`).

### Changed
- Launch wiring is centralized in `src/init.lua` via a unified side-aware launcher.
- `ClientInitializer`/`ServerInitializer` wrapper behavior is now handled directly by `Riptide.Server.Launch` and `Riptide.Client.Launch` in `init.lua`.
- CI and Release lint/format checks now include `src/`, `test/`, and `.lune/`.
- Bootstrap remote lookup in `src/init.lua` now fails fast with timeout diagnostics instead of waiting indefinitely.
- `ComponentService:Get(instance)` is deterministic: when multiple components are attached and no `tagName` is provided, it returns `nil` and warns.
- `ModuleLoader` now includes Lune task fallback for cross-runtime test stability.
- Test coverage expanded from 44 to 54 tests (including integration coverage for `ModuleLoader.Launch`, Network re-init behavior, Async input guards, and StateReplication).

### Fixed
- `Network._init` is now idempotent for re-initialization scenarios: previous event connections are disconnected before rebind.
- `Network._init` now clears stale invoke handlers during re-init and validates required deps inputs.
- Release workflow no longer runs stale cleanup step for `*.spec.lua` files.
- Test output warning noise is reduced for expected warning scenarios while preserving runtime warnings in production code paths.

### Removed
- Legacy wrapper modules `src/client/Core/ClientInitializer.lua` and `src/server/Core/ServerInitializer.lua`.

### Breaking
- Internal initializer module files were removed; any direct requires of `ClientInitializer`/`ServerInitializer` must migrate to `Riptide.Server.Launch` / `Riptide.Client.Launch` from `init.lua`.
- `ComponentService:Get(instance)` no longer returns an arbitrary component when multiple tags are attached; callers must pass explicit `tagName` in ambiguous cases.

### Internal
- Release workflow includes warning-only version preflight for tag, `pesde.toml`, and `CHANGELOG.md` consistency.
- `Async.Retry` now validates input arguments (`maxAttempts >= 1`, integer attempts, non-negative `delay`).

## [0.6.0] - 2026-03-28

### Added
- Dependency Injection for `Network` (`_init(deps)`) and `ComponentService` (`_init(deps)`), enabling mock-based testing outside Roblox.
- `ModuleLoader` module (`src/shared/ModuleLoader.lua`) — unified loading logic extracted from `ClientInitializer` and `ServerInitializer`.
- Full test suite using Lune + frktest (`test/lune/`), with mocks for `RemoteEvent`, `RemoteFunction`, and `CollectionService`.
- Lune added to `aftman.toml` toolchain.
- `.luaurc` with alias for `@src`.
- CI now runs automated tests via `lune run` on every push/PR.
- Guard stubs: `GetController` on server and `GetService` on client now throw clear errors instead of returning `nil`.

### Changed
- `ClientInitializer` and `ServerInitializer` refactored to thin wrappers (~20 lines each) over `ModuleLoader`.
- Package management fully migrated to Pesde. Wally is no longer supported.
- Tests migrated from TestEZ (Roblox-only) to frktest (Lune-native).

### Removed
- `wally.toml`, `wally.lock`, `.wallyignore` — Wally support is fully dropped.
- `DevPackages/` (TestEZ dependency).
- `dev.project.json` (was used for TestEZ in Roblox Studio).
- All `.spec.lua` files replaced by `test/lune/*.test.luau`.

### Breaking
- **Wally users must migrate to Pesde or manual `.rbxm` installation.**
- Internal `Network` module no longer self-initializes at require-time. This is transparent to end users (handled by `init.lua`), but affects anyone directly requiring `Network.lua` outside of Riptide.

## [0.5.0] - 2026-03-26

### Added
- `SharedModulesFolder` support for both `Server.Launch` and `Client.Launch`.
- `ModulesFolder` now accepts either a single `Folder` or an array of `Folder` values.
- Initializer test coverage for both client and server multi-folder/shared-folder loading paths.

### Changed
- Module loading phase now normalizes folder inputs and processes shared folders before side-specific folders.
- README launch examples updated to document `SharedModulesFolder` and multi-folder module config.
- Package manager guidance now documents dual usage (`Pesde` + `Wally`) with Pesde as the recommended path.

### Fixed
- Duplicate `ModuleScript` loads across configured folders are prevented.
- Duplicate canonical module IDs are now skipped deterministically with warning output.

### Notes
- Release target: dual publish for Wally and Pesde.
- `v0.5.0` is the last release with first-class Wally support; migration target is Pesde-first.

## [0.4.0] - 2026-03-26

### Changed
- Module registry now stores canonical module IDs based on relative path (example: `Economy/PlayerData`) instead of short name only.
- `GetModule` now resolves both canonical IDs and short aliases; ambiguous aliases require canonical path usage.
- Client and Server initializers now detect alias collisions and emit deterministic warnings.

### Fixed
- `ComponentService` startup is now idempotent: duplicate `_start` calls are ignored.
- Duplicate component construction for same `(instance, tag)` is prevented.

### Performance
- Network dispatch hot-path no longer allocates per-handler closures in `DispatchHandlers`; uses a reusable trampoline function.

### Notes
- Short-name module access remains supported as alias behavior.
- For duplicate module names in different folders, use canonical path IDs.
