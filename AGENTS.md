# Repository Guidelines

## Project Structure and Module Organization

- `Habit Tracker/` contains all Swift source files for the app (SwiftUI views, view models, and helpers).
- `Habit Tracker/Assets.xcassets` stores app icons and image/color assets.
- `Habit Tracker.xcodeproj` is the Xcode project entry point.
- There is no dedicated `Tests/` directory or test target in this repo yet.

## Build, Test, and Development Commands

- Open `Habit Tracker.xcodeproj` in Xcode 15+ and run with `Cmd+R` to build and launch on a simulator or device.
- Optional CLI build (simulator): `xcodebuild -project "Habit Tracker.xcodeproj" -scheme "Habit Tracker" -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- There are no automated tests configured; rely on manual runs in simulator/device for now.

## Coding Style and Naming Conventions

- Swift uses 4-space indentation, no tabs, and standard SwiftUI formatting.
- Types use `UpperCamelCase` (e.g., `HabitFileManager`); functions and properties use `lowerCamelCase` (e.g., `saveHabits`).
- Keep SwiftUI views small and declarative; business logic should live in view models or helper classes.
- Data persistence currently uses a user-selected file and security-scoped bookmarks; avoid hardcoding file paths.

## Testing Guidelines

- No XCTest targets exist yet. If you add tests, prefer XCTest with a `*Tests` target and name files `SomeFeatureTests.swift`.
- When changing UI behavior, manually verify key flows: add habit, mark calendar, edit/delete, and file access.

## Commit and Pull Request Guidelines

- Commit messages follow a short prefix style seen in history: `Feat: ...`, `Fix: ...`, `Misc`, `Minor ...`.
- Keep commits small and scoped; include context when behavior changes.
- Pull requests should include a brief summary, testing notes (e.g., "Tested on iPhone 15 simulator"), and screenshots or screen recordings for UI changes.

## Security and Configuration Tips

- The app stores a bookmark and original file path in `UserDefaults`; do not check in user-specific paths or exported data files.
- If file access fails, ensure the selected file still exists and is not in Trash or moved.
