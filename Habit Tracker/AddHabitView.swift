//
//  AddHabitView.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 12/1/25.
// © Blustar Software. All rights reserved.
//

import SwiftUI

struct AddHabitView: View {
    @ObservedObject var viewModel: HabitViewModel
    @Binding var newHabitName: String
    @Binding var isPresented: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                TextField("New Habit Name", text: $newHabitName)
                    .focused($isFocused)
                    .onSubmit {
                        submit()
                    }
            }
            .navigationTitle("Add New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                       submit()
                    }
                    .disabled(newHabitName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            // Add a small delay to ensure the view is ready for focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                isFocused = true
            }
        }
        .onDisappear {
            // Clean up the text field when the view disappears
            newHabitName = ""
        }
    }

    private func submit() {
        if !newHabitName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.addHabit(name: newHabitName)
            isPresented = false
        }
    }
}
