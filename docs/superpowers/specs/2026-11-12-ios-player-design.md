# iOS player and GitHub workflows design

## Intent

Turn the current SwiftUI audio player source files into a buildable iOS app with repeatable GitHub checks, while making the existing import and playback flows reliable enough for normal use.

## Goals

- Add a reproducible Xcode project definition for the existing SwiftUI app.
- Add GitHub Actions workflows that build the app on macOS for pull requests and pushes, and allow a manually triggered archive build without signing credentials.
- Restore imported tracks from the app's Documents directory at launch.
- Avoid filename collisions and handle security-scoped file access and copy/playback errors visibly.
- Keep playback controls, now-playing metadata, and the visible library in sync.
- Document local build and GitHub workflow usage.

## Non-goals

- App Store submission, code signing, TestFlight upload, or release automation requiring secrets.
- Streaming services, cloud sync, playlist editing, artwork fetching, or a broad visual redesign.
- Migrating the project to third-party audio or UI frameworks.

## Constraints

- The repository currently contains only four Swift source files and no Xcode project or package manifest.
- The app uses Apple frameworks (`SwiftUI`, `AVFoundation`, `MediaPlayer`) and therefore requires macOS/Xcode for a real iOS build.
- The current environment has no `xcodebuild`; GitHub Actions will provide the authoritative build result.

## Approaches

1. **XcodeGen project definition (recommended).** Keep the source layout and describe the app target in `project.yml`; CI installs XcodeGen and generates the project before building. This keeps project settings reviewable and reproducible, at the cost of one CI setup step.
2. **Hand-maintained `.xcodeproj`.** Check in generated Xcode project files directly. It avoids a generator dependency in CI, but makes project metadata more verbose and harder to review.
3. **Static Swift checks only.** Easy to run on generic runners, but does not validate the iOS app or Apple framework integration, so it does not meet the request for working app workflows.

## Chosen direction

Proceed with the recommended XcodeGen setup. Add pull-request and main-branch build workflows, plus a manual unsigned archive workflow. Repair import persistence and failure reporting within the current app structure. Keep changes focused on making the existing player dependable rather than adding new product features.

## Remaining implementation calls

- Use the iOS simulator SDK for CI builds and an unsigned archive for manual packaging checks.
- Restore the library by scanning the app's managed Documents audio files at launch.
- Derive stable destination filenames for same-named imports and skip files that cannot be read as audio.
- Show actionable Ukrainian error messages in the app instead of relying on console output.
- Add no release signing secrets or publishing behavior.
