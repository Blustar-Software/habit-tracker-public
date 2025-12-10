//
//  Habit_TrackerApp.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 11/25/25.
// © Blustar Software. All rights reserved.
//

import SwiftUI

@main
struct Habit_TrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            LaunchView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Verify file access when app becomes active
                HabitFileManager.shared.verifyFileAccess()
            }
        }
    }
}
