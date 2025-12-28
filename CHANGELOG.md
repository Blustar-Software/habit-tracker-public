## v1.0.0 - Current

### Added
- **Archived workflow:** Active/Archived/All filter, archive/restore flows, and confirmation prompts.
- **Bird's-eye navigation:** Bird's-eye now navigates into details inside the sheet.

### Changed
- **Archived read-only:** Archived habits open read-only with notes locked and calendar taps disabled.
- **Bird's-eye menu:** Long-press menu for habit actions in bird's-eye view.
- **Details calendar layout:** Weekday header and grid alignment/spacing refinements.

## v0.6.2

### Added
- **Archive filter:** Main list now supports Active/Archived/All views.
- **Archived indicator:** Archived habits show an "Archived" pill in the list.
- **Archive actions:** Archive/restore/delete flows include confirmations, with swipe/context options.

### Changed
- **Archived behavior:** Archived habits open read-only in details; notes read-only and calendar taps disabled.
- **Bird's-eye navigation:** Bird's-eye pushes into details inside the sheet and supports long-press menus.
- **Bird's-eye stats sheet:** Statistics now open reliably on first tap.
- **Document picker:** Removed success feedback when selecting a file.
- **Details calendar layout:** Weekday header and grid alignment/spacing refinements.

## v0.6.1

### Changed
- **Bird's-eye spacing:** Habit title layout adjusted to allow more room in compact widths.
- **Notes sheets:** Habit name appears in notes sheets for clearer context.

## v0.6.0

### Added
- **Retry habit:** Swipe, long-press, or use the details menu to reset a habit’s progress with confirmation.

### Changed
- **Main view indicators:** Unmarked habits now show centered gray dashes for streak and all-time success.
- **Details stats layout:** The chevron sits below the stats, and expanded stats push the base stats upward.

## v0.5.0 - Major new features, enhancements

### Added
- **Bird's-eye view:** A week-at-a-glance grid across all habits, with inline toggles, week navigation, and per-habit stats/notes access.
- **Notes:** Notes can now be added per habit and edited from the main list, details view, and bird's-eye view.
- **Live file reload:** The app now reloads habits when the selected `habits.json` changes or is replaced.

### Changed
- **Statistics panel:** Details view statistics are now centered with an expandable section for all-time streak and total successful days.
- **Main list actions:** Swipe, long-press, and edit-mode behaviors were refined (confirm delete, quick rename, and reorder handles).
- **File access recovery:** If the selected file is replaced at the same path, the app attempts to auto-repair access instead of forcing re-selection.

## v0.4.0 - Minor UI/UX Improvements

### Added

### Changed
- **Implicit skips:** Unmarked days no longer break a streak. If a user intends to skip certain days for the habit, they can simply leave a day unmarked.

### Fixed
- **Details View statistics section:** The statistics section in the Details View is now stable, sticking to the lower portion of the screen instead of moving around when the view is opened.
- **Main View edit button:** The background around the edit button in the Main View no longer sticks after bulk habit deletion.

## v0.3.0 – Enhancements and UI/UX Refinements

### Added
- **Current Day Indicator:** The calendar view now features a yellow ring around the current day for better visibility.
- **Current Streak Indicator on Main View:** A colored circle displaying the current streak (red for 0, green for >0, "99+" for streaks over 99) has been added to the main habit list. The circles were also enlarged and properly aligned.
- **Habit Reordering:** Habits on the main view can now be reordered using drag-and-drop.

### Changed
- **Success Percentage Coloring:** The success percentages on the main view are now color-coded in even thirds: red for 0-33%, yellow for 34-66%, and green for 67-100%.
- **Sound Feedback:**
    - Days marked as success now use system sound 1103.
    - Days marked as unsuccessful now use system sound 1105.
    - Unmarking a day now uses system sound 1104.
    - Month navigation buttons also use system sound 1104.
- **Toolbar Button Transitions:**
    - The "Edit" / "Done" button in the top-left corner now transitions instantly without a fade.
    - The trash can button now seamlessly replaces the plus sign button in the top-right corner when entering edit mode.

### Fixed
- **Streak Calculation Accessibility:** The `currentStreak` function was moved to `HabitViewModel` to resolve scope errors and ensure proper access from `ContentView`.
- **UI Alignment:** Corrected the alignment of streak circles and success percentages on the main view to ensure consistent vertical positioning.

## v0.2.0 – Major UI/UX Overhaul and Feature Enhancement

### Added
- **Batch Deletion:** You can now select and delete multiple habits at once! Tap "Edit" on the main screen to enter selection mode.
- **Haptics & System Sounds:** The app now provides satisfying physical feedback for actions like completing, deleting, and adding habits.
- **Custom Launch Screen:** A new launch screen featuring the Blustar logo now greets you on startup.
- **Cancel New Habit:** Added a "Cancel" button when creating a new habit, so you no longer have to press "Add" to dismiss the keyboard.

### Changed
- **Add Habit Flow:** The text field for adding new habits has been replaced with a cleaner, modal pop-up window, accessible via the new '+' icon in the top right corner.

### Fixed
- **Streak Calculation:** The "Current Streak" logic has been completely overhauled. It now correctly handles days that are unmarked or marked as failed (red), so your streak count is always accurate.

## v0.1.0 – Initial Habit Tracker MVP
### Added
- Ability to add new habits
- Swipe-to-delete individual habits
- Bulk delete option
- Main habit list with success percentage
- Habit Details page with full month display
- Navigation between months
- Tap-to-toggle day success/failure
- Streak indicator and all-time success rate
