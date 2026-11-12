# iOS Player and GitHub Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing SwiftUI audio player buildable and dependable, with GitHub Actions building it on every pull request and main push.

**Architecture:** Define the iOS app with XcodeGen, keeping the four existing app sources at the repository root. Extract local-file import and library restoration into a testable store, report errors through SwiftUI, and use macOS GitHub runners for simulator tests and unsigned archive builds.

**Tech Stack:** Swift, SwiftUI, AVFoundation, XCTest, XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-12-ios-player-design.md`

## Global Constraints

- The app uses Apple frameworks and requires macOS/Xcode for a real iOS build.
- Use XcodeGen to describe the app project.
- CI builds on macOS for pull requests and pushes to `main`.
- Manual archive builds remain unsigned and require no repository secrets.
- Restore imported audio from the app-managed Documents directory.
- Show actionable Ukrainian import and playback errors.
- Do not add release signing or publishing behavior.
- Commit each coherent task and push it to `origin/main`; never force-push.

## Review Focus

- Two imported files share a basename: test that both are preserved with distinct destination paths and contents.
- The app's Documents directory contains a deleted or unsupported file: test that restoration skips it and returns only supported audio files that still exist.
- An imported source is unreadable or cannot be copied: test that the store reports the failure without leaving a partial library entry.
- The app is launched with existing managed audio: test that restoration returns the same files in deterministic order.
- Playback is requested without a loadable player: review and verify that the UI does not claim playback started and exposes the failure.

---

### Task 1: Add a reproducible Xcode project and GitHub workflows

**Files:**
- Create: `project.yml`
- Create: `.gitignore`
- Create: `.github/workflows/ios.yml`
- Create: `.github/workflows/archive.yml`
- Create: `README.md`
- Modify: `project.yml` as needed to define the app and unit-test targets.

**Interfaces:**
- Produces Xcode scheme `illia`, app target `illia`, and test target `illiaTests`.
- The CI test workflow generates `illia.xcodeproj`, selects an available iPhone simulator by UDID, and runs `xcodebuild test`.
- The archive workflow runs only on manual dispatch and uploads an unsigned `.xcarchive` artifact.

- [ ] **Step 1: Add project definition and basic build instructions.** Set the iOS deployment target to 16.0, bundle identifier to `com.kurganskijilla2.illia`, and include the existing Swift files in app target `illia`.
- [ ] **Step 2: Add GitHub Actions workflows.** Run tests on pull requests and pushes to `main`; add a separate manual unsigned archive workflow. Pin third-party actions to major versions and grant only read permissions plus artifact upload permissions where needed.
- [ ] **Step 3: Add ignore rules.** Ignore Xcode user state, derived data, generated project output if regenerated, and build archives.
- [ ] **Step 4: Document local generation, build, test, and manual archive commands.**
- [ ] **Step 5: Verify available local tools.** Run `xcodegen generate` and `xcodebuild -list` when present; otherwise record the missing macOS toolchain and rely on the workflow result.
- [ ] **Step 6: Commit and push.** Commit as `ci: add iOS Xcode project and GitHub workflows`, then push the commit to `origin main` without force.

### Task 2: Test and implement persistent track library storage

**Files:**
- Create: `TrackLibraryStore.swift`
- Create: `illiaTests/TrackLibraryStoreTests.swift`
- Modify: `Track.swift`
- Modify: `AudioManager.swift`
- Modify: `project.yml`

**Interfaces:**
- `TrackLibraryStore.init(directoryURL:fileManager:)` owns import and restore operations within the app-managed directory.
- `TrackLibraryStore.restoreTracks() -> [Track]` returns existing supported audio files in deterministic filename order.
- `TrackLibraryStore.importTracks(from:) -> TrackImportReport` copies available scoped files into the managed directory, assigns unique destinations for collisions, and returns successes plus per-file failures so one bad selection does not discard successful imports.

- [ ] **Step 1: Write XCTest cases** for deterministic restore, ignored missing/unsupported files, duplicate basenames preserving both file contents, failed-copy cleanup, manager startup restoration, and partial-success import handling.
- [ ] **Step 2: Run the XCTest target** and confirm the new behavioral cases fail before implementation.
- [ ] **Step 3: Implement `TrackLibraryStore`** with Foundation file operations, supported audio extensions, collision-safe names, security-scoped access cleanup, and partial-copy cleanup.
- [ ] **Step 4: Run the XCTest target** and confirm all store tests pass.
- [ ] **Step 5: Update `AudioManager`** to load the store on initialization and use it for imports without dropping earlier library entries on a single-file failure.
- [ ] **Step 6: Commit and push.** Commit as `fix: persist and safely import audio tracks`, then push to `origin main` without force.

### Task 3: Surface import and playback failures in the player

**Files:**
- Modify: `AudioManager.swift`
- Modify: `ContentView.swift`
- Modify: `illiaTests/AudioManagerPlaybackTests.swift`
- Modify: `illiaTests/TrackLibraryStoreTests.swift`

**Interfaces:**
- `AudioManager.errorMessage: String?` publishes a user-facing Ukrainian error.
- A failed import or player initialization sets `errorMessage`; successful user actions clear stale errors.
- `ContentView` presents `errorMessage` in a dismissible alert.

- [ ] **Step 1: Add focused tests** that the play control without a loaded player remains paused and publishes a Ukrainian error, and that a partial import exposes the failed filename while retaining imported tracks.
- [ ] **Step 2: Verify the test fails** before changing playback state handling.
- [ ] **Step 3: Implement error publication and alert presentation.** Ensure a failed track load clears any previous player, `isPlaying` reflects the actual result of `AVAudioPlayer.play()`, and lock-screen elapsed-time metadata refreshes during playback.
- [ ] **Step 4: Run all XCTest cases** and inspect the Swift changes for consistent error clearing and track state.
- [ ] **Step 5: Commit and push.** Commit as `fix: report audio playback and import errors`, then push to `origin main` without force.

### Task 4: Verify and document the final GitHub process

**Files:**
- Modify: `README.md`
- Modify: workflow files only if verification reveals a defect.

- [ ] **Step 1: Re-read the design and this plan** and check every stated goal against the repository.
- [ ] **Step 2: Run local static checks** for YAML syntax, project configuration consistency, and `git diff --check`.
- [ ] **Step 3: Inspect GitHub Actions results** for the pushed commits; fix and push any workflow or compile failures.
- [ ] **Step 4: Confirm the working tree is clean** and report the commit IDs and workflow status without claiming a build passed unless GitHub reports success.
