Blustar Software – Habit Tracker

© Blustar Software

⸻

Overview

Habit Tracker is an intuitive iOS application designed to help users build and maintain positive habits. With a clean interface, users can easily add, track, and manage their daily habits. 
Key features include a detailed calendar view for tracking daily completion, a dynamic streak indicator to motivate progress, and monthly success percentages that provide at-a-glance performance insights. 
The app supports habit reordering, advanced sorting (by monthly success), bulk management (archive, restore, delete), and provides subtle haptic and sound feedback for a satisfying user experience.

⸻

Philosophy

Blustar Software values clarity, symbolic design, and purposeful interaction. Every element of this project—from interface to code—reflects a deliberate framework for deep engagement.

⸻

Installation
  1. Clone the repository:

```git clone https://github.com/Blustar-Software/Habit-Tracker.git```

  2. Open Habit Tracker.xcodeproj in Xcode (15+ recommended).
  3. Build and run on your device or simulator.
(Requires a personal Apple developer team for local builds.)

Data Storage

Habit data is stored in a user-selected `habits.json` file. You can keep it in iCloud Drive to sync across devices, and the app will reload when the file changes or is replaced at the same path.

New in v1.1.2

- **Monthly Statistics Focus:** The main view, bird's-eye view, and sorting logic now prioritize current-month performance to encourage fresh starts and consistent progress.
- **Dynamic Detail Stats:** The statistics section in the Detail view now automatically calculates success rates based on the month currently being viewed in the calendar.
- **Color-Coded Streaks:** Habit streaks are now visually distinguished (Green for active, Red for broken) for immediate status recognition.

New in v1.1.1

- **Advanced Sorting:** Toggle between "Manual" and "Sorted" (by success rate) via the new toolbar menu.
- **Bulk Management:** New "Actions" menu in edit mode for bulk archiving, restoring, and resetting habits.
- **Select All:** Quickly select or deselect your entire filtered list in edit mode.
- **Sound Restoration:** Re-implemented native system sounds for completion feedback.
- **Stabilized Bird's-Eye:** Habit order now remains stable while checking days in the Bird's-Eye view.

⸻

Usage

**1. Adding a New Habit:**
   - Tap the '+' icon in the top-right corner of the main screen.
   - Enter the name of your new habit and tap 'Add'.

**2. Tracking Habit Completion:**
   - On the main list, tap any habit to view its details.
   - In the calendar view, tap a day to mark it as completed (green circle), unsuccessful (red circle), or unmarked (gray circle).
   - The current day is highlighted with a yellow ring.

**3. Sorting and Filtering:**
   - **Filter:** Use the segmented picker at the top to view Active, Archived, or All habits.
   - **Sort:** Tap the sort icon (up/down arrows) in the toolbar to switch between Manual (custom order) and Sorted (monthly success rate) views.

**4. Bulk Management (Edit Mode):**
   - Tap 'Edit' to enter selection mode.
   - Use 'Select All' in the top-left to manage your entire list at once.
   - Access the 'Actions' (ellipsis) menu to Archive, Restore, Reset, or Delete selected habits. The menu intelligently shows only valid actions for your selection.

**5. Bird's-Eye View:**
   - Tap the bird icon to see a high-level view of your week's progress across all habits. 
   - Tap any dot to quickly toggle completion status without leaving the view.

⸻

Future Roadmap

- Implement Liquid Glass UI
- Enable cloud syncing, with adequate conflict resolution, to enable use across devices
- Fix bugs

⸻

Contributing

Blustar Software projects are currently single-author. Contributions are welcome via forks or suggestions.
Respect the minimalist and symbolic design ethos when proposing changes.

⸻

License

© Blustar Software. All rights reserved.
