# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Planned]

### Added
- State machine module (workflow/state orchestration) for gameplay and service-level flows.

### Changed
- Package management roadmap includes migration from Wally-only flow to Pesde workspace-compatible flow.

### Fixed
- _No entries yet._

### Performance
- _No entries yet._

### Deprecated
- _No entries yet._

### Breaking
- _No entries yet._ 

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
