# GEMINI.md

## Project Overview

This is an iOS Habit Tracker application written in Swift using the SwiftUI framework. The app allows users to create, track, and manage their daily habits. Key features include:

*   **Habit Tracking:** Users can add, rename, and delete habits.
*   **Calendar View:** A detailed calendar view to mark habits as completed, unsuccessful, or unmarked for each day.
*   **Streak Counter:** A visual indicator to show the current streak for each habit, color-coded for quick status checks.
*   **Success Percentage:** Customizable metrics showing either All-Time or Monthly success rates across the app.
*   **Progress Reports:** Automated weekly (Monday) and monthly (1st) performance summaries with a built-in informational guide.
*   **Data Persistence:** Consolidated `HabitData` structure (habits and reports) stored in a user-selected JSON file via `HabitFileManager`.
*   **User Feedback:** The app provides haptic and sound feedback for various user interactions.

The project follows a Model-View-ViewModel (MVVM) architecture, with `ContentView`, `HabitDetailView`, `BirdsEyeView`, and `ReportsListView` as the primary Views.

## Building and Running

1.  **Open the project in Xcode:**
    *   Open the `Habit Tracker.xcodeproj` file in Xcode (version 15 or newer is recommended).

2.  **Select a Simulator or Device:**
    *   Choose an iOS simulator (e.g., iPhone 15) or a connected Apple device from the scheme menu at the top of the Xcode window.

3.  **Run the app:**
    *   Click the "Run" button (the play icon) or press `Cmd+R`.

*Note: Building on a physical device may require a personal Apple Developer account.*

## Development Conventions

*   **SwiftUI:** The user interface is built declaratively using SwiftUI.
*   **MVVM:** The project is structured using the Model-View-ViewModel pattern to separate UI from business logic.
*   **`ObservableObject`:** The `HabitViewModel` is an `ObservableObject` that the views subscribe to for updates.
*   **`Codable`:** The `Habit` model conforms to the `Codable` protocol for easy serialization to and from `UserDefaults`.
*   **Feedback:** A `FeedbackManager` singleton is used to centralize haptic and sound feedback.
*   **Minimalist Design:** The `README.md` emphasizes a minimalist and symbolic design ethos.

## Future Roadmap (iOS 26 Refactor)

A proposal has been drafted to align the app with the **Liquid Glass** design system introduced in iOS 26.

### Key Objectives:
*   **Visual Overhaul:** Transition from flat design to a tactile, refractive aesthetic.
*   **Dynamic Backgrounds:** Implement `MeshGradient` to provide color depth for glass refraction.
*   **GlassMorphing:** Use `GlassEffectContainer` and `.glassEffect()` modifiers to allow UI elements (like habit cards and toolbars) to "melt" and merge organically.
*   **Interactive Physics:** Add surface-tension animations and haptic feedback synchronized with the "liquid" feel of the interface.

*Note: Implementing this roadmap requires bumping the deployment target to iOS 26.0.*

