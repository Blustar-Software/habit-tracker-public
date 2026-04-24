# Habit Tracker

*© Blustar Software*

## Overview

Habit Tracker is an intuitive iOS application designed to help users build and maintain positive habits through a framework of Implicit Intent. Unlike trackers that penalize you for every day you don’t log, this app respects the distinction between a "failed" day and a "non-habit" day.

Key features include a detailed calendar view, a dynamic streak indicator, success percentages, and a "Bird’s-Eye" progress view. The app supports habit reordering, advanced sorting, and bulk management, all delivered with subtle haptic and sound feedback.

## 🧠 Philosophy: Implicit Intent

Blustar Software values clarity, symbolic design, and purposeful interaction. Most trackers fail because they treat every day as a "habit day," leading to "streak fatigue." This project reflects a more deliberate framework:

•    Green: You showed up and did it.
•    Red: You intended to do it, but didn't (The streak resets).
•    Unmarked: You never intended to do it today. (The streak stays alive).

Every element of this project—from interface to code—is designed to support this reality of flexible, sustainable habit building.

## 🛠 Installation & Developer Setup

This project is shared as-is for local deployment via Xcode. To get it running on your device:

    1.    Clone the repository:
    2.    Open in Xcode: Open Habit Tracker.xcodeproj (Xcode 15+ recommended).
    3.    Configure Signing: Because this is a private project, you must go to Target > Signing & Capabilities, update the Bundle Identifier to a unique string, and select your own Personal Development Team.
    4.    Build and Run: Connect your iPhone or use the Simulator and hit Cmd + R.

## 📂 Data Sovereignty

Your habit data is stored in a user-selected habits.json file.
•    Ownership: Your data is a flat JSON file, not a hidden database.
•    Privacy by Design: To avoid the complexities and privacy trade-offs of cloud syncing, the app is currently single-device.
•    Local Storage: You can store your habit file directly in the "On My iPhone" local directory. This keeps your data entirely offline, off-grid, and under your physical control.
•    Live Updates: The app automatically reloads when the file is modified or replaced at the same path.

## New in v1.1.1

•    Advanced Sorting: Toggle between "Manual" and "Sorted" (by success rate).
•    Bulk Management: New "Actions" menu for archiving, restoring, and resetting habits.
•    Select All: Quickly manage your entire list in edit mode.
•    Sound Restoration: Re-implemented native system sounds for completion feedback.
•    Stabilized Bird's-Eye: Fixed ordering issues when toggling days in high-level view.

## Usage

1. Tracking Habit Completion:

In the calendar view, tap a day to cycle through status:
•    Green: Completed.
•    Red: Unsuccessful (Intent was present, action was not).
•    Gray: Unmarked (Neutral/No Intent).
•    The current day is highlighted with a yellow ring.

*Note: it is recommended that you write your intentions in the notes section for each habit, or elsewhere*

2. Bird's-Eye View:

Tap the bird icon for a high-level cross-habit view of your week. You can toggle completion status directly from this view.

3. Sorting and Filtering:

Use the segmented picker for Active/Archived status, and the sort icon to switch between Manual and Success Rate sorting.

## Future Roadmap

•    Implement Liquid Glass UI
•    Enable cloud syncing with robust conflict resolution
•    Fix bugs

### Contributing & License

Blustar Software projects are currently single-author. Contributions are welcome via forks or suggestions that respect the minimalist and symbolic design ethos.

*© Blustar Software. All rights reserved.*
