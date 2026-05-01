Blustar Software – Habit Tracker

© Blustar Software

⸻

Overview

Habit Tracker is an intuitive iOS application designed to help users build and maintain positive habits. With a clean interface, users can easily add, track, and manage their daily habits. 
Key features include a detailed calendar view for tracking daily completion, a dynamic streak indicator to motivate progress, and customizable success percentages (choose between All-Time or Monthly focus). 
The app supports habit reordering, advanced sorting, automated progress reports, and provides subtle haptic and sound feedback for a satisfying user experience.

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

- **Stat Mode Toggle:** Choose between **All-Time** or **Monthly** statistics in the view options menu. The entire app (including sorting) adapts to your preference.
- **Progress Reports:** Automatically generates weekly (every Monday) and monthly (1st of the month) summaries. If you miss any period, separate reports are generated for each missed week or month.
- **In-app Guide:** A new informational guide accessible from the Reports view explains the app's smart logic and statistics.
- **Hybrid Stability Sorting:** In Monthly mode, sorting uses last month's data as a tie-breaker for a stable experience during month transitions.
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

**3. View Options (Sort & Stats):**
   - Tap the **View Options** icon (up/down arrows) in the toolbar.
   - **Sort By:** Toggle between Manual (custom order) and Sorted (by success rate).
   - **Stat Mode:** Toggle between All-Time (lifetime history) and Monthly (current calendar month).

**4. Progress Reports & Guide:**
   - Tap the **Reports** icon (document with magnifying glass) to view your performance history.
   - Look for the red badge indicating new, unread reports.
   - Inside the Reports view, tap the **Info** button to read the guide on how the app calculates data.

**5. Bulk Management (Edit Mode):**
   - Tap 'Edit' to enter selection mode.
   - Use 'Select All' in the top-left to manage your entire list at once.
   - Access the 'Actions' (ellipsis) menu to Archive, Restore, Reset, or Delete selected habits. The menu intelligently shows only valid actions for your selection.

**6. Bird's-Eye View:**
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
