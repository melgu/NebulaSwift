# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

NebulaSwift is an unofficial SwiftUI client for the Nebula streaming service, for iPhone, iPad and Mac (native macOS, not Catalyst). One target, one scheme (`NebulaSwift`), no Swift packages, no test target, no linter.

## Building and deploying

- **Build check:** Xcode MCP `BuildProject` on the `NebulaSwift.xcodeproj` workspace (`XcodeListWorkspaces` for its id, `XcodeOpenWorkspace` if missing). Prefer it over `xcodebuild`: only Xcode's own build extracts new strings into `NebulaSwift/Localizable.xcstrings`.
- **Command line, if needed:** `xcodebuild -project NebulaSwift.xcodeproj -scheme NebulaSwift -destination 'generic/platform=iOS' build` (or `-destination 'platform=macOS'`). Build both platforms when touching `#if os(...)` code.
- **Deploy:** `./deploy.sh` builds Debug and installs (without launching) on every reachable paired iOS device via `devicectl`. A stray "error: the following command failed with exit code 0 but produced no further output" line from its device discovery is harmless when the installs report "App installed". If the script can't be used, deploy with the Xcode MCP (`BuildProject`/`RunProject`) instead.

Settings that shape the code: Swift 6 with `SWIFT_STRICT_CONCURRENCY = complete`, iOS 17 / macOS 14 deployment targets (newer APIs behind `#available`, e.g. `BGContinuedProcessingTask` on iOS 26). The `NebulaSwift/` folder is a synchronized group, so new files are picked up without editing `project.pbxproj`.

## Localization

Languages are English (source) and German. `Localizable.xcstrings` holds UI strings, `AppShortcuts.xcstrings` the App Shortcuts phrases. Every new user-facing string needs a `de` translation in the catalog after the Xcode build added it.

## Architecture

**Shared state.** `NebulaSwiftApp` creates four `@MainActor @Observable` objects and injects them with `.environment(...)`; views read them with `@Environment(API.self)` etc.:
- `API` (`API/`) – the Nebula client. One `extension API` file per area (`API+Video.swift`, `API+Channel.swift`, …) defines the models and their endpoints as async properties/functions on top of the generic `request(...)` in `API/Network.swift`. That layer adds `Token`/`Bearer` authorization, snake_case JSON coding, and on 401/403 refreshes the bearer once and retries, logging out when that fails. Base URLs come from the app config (`refreshConfiguration()`) and are persisted. Paged endpoints decode into `ListContainer`.
- `Storage` – user settings, each persisted to `UserDefaults` in its `didSet`. Keys live in `Defaults`.
- `DownloadManager` (`Downloads/`) – offline downloads, see below.
- `Player` (`Views/Basics/Player.swift`) – the single `AVPlayer`, Picture in Picture, audio session handling for hover/peek previews, and progress reporting through `ProgressSync`, which saves watch progress locally before sending it so it survives being offline.

**Navigation.** `ContentView` is the root: `Login` when logged out, otherwise a `NavigationSplitView` whose sidebar picks a `TopLevel` page (the `StartPage` cases, search, or a channel from My Shows), each in a `NavigationStack`. Everything that opens content funnels into a few paths there:
- the `openItem` environment action (`Views/Basics/Navigation.swift`) – a `Video` opens the player, anything else is pushed on the stack;
- `nebulaswift://video|channel|page|search/...` URLs, used by App Intents (`Intents/`), Home Screen quick actions (`QuickAction`, `SceneDelegate` in `AppDelegate.swift`) and the macOS Dock menu;
- Handoff user activities `de.melgu.NebulaSwift.video` / `.channel`.

**Error handling.** Views report errors through the `handleError` environment action (`Views/Basics/ErrorHandling.swift`), shown as an alert by `.alertErrorHandling()`. Async UI uses `AsyncButton`, `AsyncNavigationLink` and the async `onTapGesture` overloads, which route thrown errors there. Content that fails to load initially shows `LoadingErrorView`; cancellations are filtered via `Error.isCancellation`.

**Downloads.** `DownloadManager` queues downloads one at a time and persists its index (`Downloads.json`), thumbnails and partial downloads in Application Support. Finished files go to Documents on iOS (visible in Files) or `~/Movies/NebulaSwift Offline` on macOS, named with the episode id so they're found again after renames. The actual download is behind the `VideoDownloader` protocol, implemented by `HLSDownloader`: it parses the HLS playlists (`HLSPlaylist`), fetches the fMP4 segments of the chosen variant plus all audio and subtitle renditions into resumable `FragmentedMP4File`s (renumbering fragments so AVFoundation reads them), converts WebVTT subtitles, and `MP4Muxer` combines everything into one MP4 with metadata, without re-encoding. On iOS, `DownloadBackgroundActivity` keeps the queue running in the background (a `BGContinuedProcessingTask` on iOS 26, otherwise the usual background time) and the queue pauses when that time expires. The player prefers a downloaded file over the stream.

**Platform split.** iOS and macOS share nearly all code; differences are inline `#if os(iOS)` / `#if os(macOS)` (or `canImport(UIKit)`), including two different `AppDelegate`s and a separate macOS `Settings` scene.

## Conventions

- Tabs for indentation. Doc comments (`///`) describe what something is for, in plain sentences; inline comments explain non-obvious reasons.
- Commit subjects are plain imperative sentences describing the user-visible change (no Conventional Commits prefixes).
