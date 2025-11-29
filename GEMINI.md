# GEMINI.md

## Project Overview

This is an iOS Habit Tracker application written in Swift using the SwiftUI framework. The app allows users to create, track, and manage their daily habits. Key features include:

*   **Habit Tracking:** Users can add, rename, and delete habits.
*   **Calendar View:** A detailed calendar view to mark habits as completed, unsuccessful, or unmarked for each day.
*   **Streak Counter:** A visual indicator to show the current streak for each habit.
*   **Success Percentage:** Calculates and displays the all-time success rate for each habit.
*   **Data Persistence:** Habit data is stored locally using `UserDefaults`.
*   **User Feedback:** The app provides haptic and sound feedback for various user interactions.

The project follows a Model-View-ViewModel (MVVM) architecture, with `ContentView` and `HabitDetailView` as the Views, `Habit` as the Model, and `HabitViewModel` as the ViewModel.

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
