# Repository Guidelines

## Project Structure & Module Organization

- `Habit Tracker/` holds all Swift source (SwiftUI views, view model, and helpers). Key files: `ContentView.swift` (main UI and `HabitViewModel`), `HabitFileManager.swift` (persistence, bookmarks, file change handling), `FileSelectionView.swift` (document picker flow), `AddHabitView.swift`, `LaunchView.swift`, and `FeedbackManager.swift`.
- `Habit Tracker/Assets.xcassets` stores icons, colors, and images.
- `Habit Tracker.xcodeproj` is the Xcode project entry.
- There is no `Tests/` directory or test target yet.

## Build, Test, and Development Commands

- Open `Habit Tracker.xcodeproj` in Xcode 15+ and run with `Cmd+R` on a simulator or device.
- Optional CLI build (simulator): `xcodebuild -project "Habit Tracker.xcodeproj" -scheme "Habit Tracker" -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Automated tests are not configured; use manual verification for core flows.

## Coding Style & Naming Conventions

- 4-space indentation, no tabs; keep SwiftUI formatting consistent with the existing files.
- Types use `UpperCamelCase`; functions/properties use `lowerCamelCase`.
- Keep view bodies readable; extract helpers or subviews when a body becomes hard to scan.
- Data persistence flows through `HabitFileManager` with a security-scoped bookmark to a user-selected `habits.json`; avoid hardcoded paths.

## Testing Guidelines

- No XCTest targets yet. If you add tests, create a `Habit TrackerTests` target and name files `FeatureTests.swift`.
- Manually check: file selection, add/rename/delete, calendar marking, retry flow, and file reload after external changes.

## Commit & Pull Request Guidelines

- Commit messages use short prefixes like `Feat:`, `Fix:`, `Add:`, or `Change:` followed by a concise description.
- Keep commits scoped to one behavior change; include testing notes and UI screenshots in PRs.

## Configuration & Data Notes

- `habits.json` can live in iCloud Drive for multi-device use; file change notifications should trigger reloads.
- Do not commit user data files or security-scoped bookmark information.
