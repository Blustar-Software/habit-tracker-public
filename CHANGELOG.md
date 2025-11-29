## v0.4.0 - $

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
