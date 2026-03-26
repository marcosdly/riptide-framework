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
