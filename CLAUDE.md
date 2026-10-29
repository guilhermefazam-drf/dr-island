# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Dr Island (formerly "Token Island"): a native macOS 14+ menu-bar app (`LSUIElement`, accessory policy) that draws a "Dynamic Island" around the MacBook notch (a 150pt pill on screens without one). It shows Claude usage/cost, GitHub PRs, Jira tasks and sprint, music, a focus timer and app shortcuts; hovering expands it. Built for the Doutor Finanças dev team.

User-facing text, README and `docs/` are in European Portuguese; code and comments are in English. `docs/funcionalidades.md` is the factual inventory of every feature and business rule — keep it in sync when behaviour changes.

## Commands

Pure SwiftPM, no Xcode project.

```bash
scripts/bundle.sh release          # build DrIsland.app (ad-hoc signed); also `debug`
scripts/dmg.sh                     # release build + DrIsland-<VERSION>.dmg
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SprintTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter "SprintTests/progressIsClampedAndLinear"
open DrIsland.app
```

- Plain `swift build` fails: the macOS 27 SDK in the Command Line Tools lacks the SwiftUI macro plugin, so `bundle.sh` pins `MacOSX26.sdk` (override with `SDKROOT_OVERRIDE`). Always build the app through `bundle.sh`; `swift test` with `DEVELOPER_DIR` set to Xcode works directly.
- The app must run as the bundled `.app` for notifications, Keychain "Always Allow" and login-item behaviour.
- Version lives in `VERSION`. Signing for distribution: `CODESIGN_IDENTITY=… NOTARY_PROFILE=… scripts/dmg.sh`.
- Debug env vars: `DR_ISLAND_SNAPSHOT=<png>` writes a render of the island (and `.menubar.png`), `DR_ISLAND_FAKE=0..1` forces the Claude % without network, `DR_ISLAND_COLLAPSED` keeps it collapsed.

## Architecture

Two modules (see `Package.swift`):

- **`DrIslandCore`** — pure, testable logic with no UI: API clients and parsers (`UsageClient`, `GitHubClient`, `Jira`, `Sprint`), diffing that produces alerts (`PullRequestChanges` → `PRChange`), cost/usage math, quiet hours, focus timer, layout config, Keychain/secret access. All tests target this module (Swift Testing: `import Testing`, `@Suite`/`@Test`/`#expect`). New logic should go here so it can be tested.
- **`DrIsland`** — the AppKit/SwiftUI app. `main.swift` → `AppDelegate`, which owns one `ObservableObject` store per source (`UsageStore`, `PullRequestStore`, `JiraStore`, `MusicStore`, `CostStore`, `FocusStore`) and hands them all to `IslandController`.

Key flows:

- **Stores** are `@MainActor` and run their own async refresh loop (`start()`), with a `Status` enum, backoff on failures, `isRefreshing`/`inFlight` flags, and a persisted fingerprint baseline in UserDefaults used to detect changes between readings.
- **Alerts** are funnelled through `PullRequestStore`: other sources report `[PRChange]` into it (`jiraStore.onAlert` → `prStore.register`, network/Claude-session events → `prStore.showTransient`). It then fans out to the configured channels (border pulse, dot, row tag, banner, confetti, macOS notification, sound), subject to quiet hours and mutes.
- **Island UI**: `IslandController` creates one `IslandPanel` (transparent, click-through `NSPanel`) per screen via `IslandInstance`, handles fullscreen hiding and hover. `IslandView` renders it; each card is an `IslandBlock` placed in 1–3 columns according to `IslandLayoutConfig` (the shortcuts dock is always centred below and is not a block). Adding a new card means a new `IslandBlock` case plus its view in `IslandBlocks.swift`/`DayBriefingBlocks.swift` and layout handling.
- **Settings**: non-secret prefs are UserDefaults keys declared in `SettingsKey` with defaults in `Settings.registerDefaults()`; secrets (Jira token) live only in the Keychain. The Settings window is split across `Settings*.swift` views.
- **External sources**: Claude reads the Claude Code OAuth token from the Keychain via `/usr/bin/security` (so "Always Allow" survives rebuilds) and calls the undocumented `api.anthropic.com/api/oauth/usage`; GitHub shells out to the `gh` CLI (auto-located in `/opt/homebrew/bin`, `/usr/local/bin` or `/usr/bin` unless overridden in Settings, since a GUI app has no shell `PATH`; never stores tokens); Jira uses the Cloud REST API with email + API token. The "Aprovações" section depends on the DF-specific `customfield_10127`; the Sprint field is auto-discovered. PRs are matched to sprint tasks only by Jira key in the PR title.
- **Music**: Spotify and Apple Music are read and controlled via `NSAppleScript` on one serial queue (it is not thread-safe). System-wide Now Playing (e.g. browsers) comes from `helper/nowplaying.c`, compiled by `bundle.sh` into `libnowplaying.dylib` and loaded inside `/usr/bin/perl` via `nowplaying.pl`; without the bundle that source is simply absent.
- `ErrorLog` records source errors, exceptions, crashes and UI hangs to a file, viewable from the menu bar ("Registo de erros…").
