    //
//  ContentView.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 11/25/25.
// © Blustar Software. All rights reserved.
//

import SwiftUI
import Combine

struct Habit: Identifiable, Codable {
    let id: UUID
    let name: String
    var completion: [String: Bool] = [:] // key: date string (e.g., "2025-11-25")
    
    init(id: UUID = UUID(), name: String, completion: [String: Bool] = [:]) {
        self.id = id
        self.name = name
        self.completion = completion
    }
}

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    
    private let saveKey = "SavedHabits"
    
    init() {
        loadHabits()
    }
    
    func addHabit(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let newHabit = Habit(name: trimmedName)
        habits.append(newHabit)
        saveHabits()
    }
    
    func renameHabit(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index] = Habit(id: habits[index].id, name: trimmed, completion: habits[index].completion)
        saveHabits()
    }

    func deleteHabit(id: UUID) {
        if let index = habits.firstIndex(where: { $0.id == id }) {
            habits.remove(at: index)
            saveHabits()
        }
    }
    
    func deleteHabits(ids: Set<UUID>) {
        habits.removeAll { ids.contains($0.id) }
        saveHabits()
    }
    
    func removeHabits(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
        saveHabits()
    }
    
    func moveHabits(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        saveHabits()
    }
    
    func markCompletion(habitId: UUID, dateString: String, completed: Bool) {
        if let index = habits.firstIndex(where: { $0.id == habitId }) {
            habits[index].completion[dateString] = completed
            saveHabits()
        }
    }

    func removeCompletion(habitId: UUID, dateString: String) {
        if let index = habits.firstIndex(where: { $0.id == habitId }) {
            habits[index].completion.removeValue(forKey: dateString)
            saveHabits()
        }
    }
    
    func isCompleted(habitId: UUID, dateString: String) -> Bool? {
        if let habit = habits.first(where: { $0.id == habitId }) {
            return habit.completion[dateString]
        }
        return nil
    }
    
    func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
                habits = decoded
                return
            }
        }
        habits = []
    }
    
    func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func successPercentage(for habit: Habit) -> Double {
        let marked = habit.completion.values
        let total = marked.count
        guard total > 0 else { return 0 }
        let successes = marked.filter { $0 == true }.count
        return (Double(successes) / Double(total)) * 100.0
    }
    
    func successPercentage(for habit: Habit, year: Int, month: Int) -> Double {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        let filtered: [Bool] = habit.completion.compactMap { (key, value) in
            // key format yyyy-MM-dd
            let comps = key.split(separator: "-")
            guard comps.count == 3,
                  let y = Int(comps[0]),
                  let m = Int(comps[1]) else { return nil }
            return (y == year && m == month) ? value : nil
        }
        let total = filtered.count
        guard total > 0 else { return 0 }
        let successes = filtered.filter { $0 == true }.count
        return (Double(successes) / Double(total)) * 100.0
    }
    
    // Helper to compute current streak. Unmarked days are ignored, and only unsuccessful days break the streak.
    func currentStreak(for habit: Habit) -> Int {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        let calendar = Calendar.current
        var streak = 0
        
        var currentDay = calendar.startOfDay(for: Date())
        var foundFirstMarkedDay = false

        // Iterate backwards from today for up to 5 years to find the streak.
        for _ in 0..<(365 * 5) {
            let key = df.string(from: currentDay)
            let status = isCompleted(habitId: habit.id, dateString: key)

            if let completionStatus = status { // Day is marked (true or false)
                if !foundFirstMarkedDay {
                    if completionStatus == false {
                        // The most recent marked day is a failure. Streak is 0.
                        return 0
                    }
                    // This is the first successful day found. Start the streak.
                    foundFirstMarkedDay = true
                    streak = 1
                } else {
                    // Already in a streak.
                    if completionStatus == true {
                        streak += 1
                    } else { // completionStatus is false
                        // Streak is broken by a failure.
                        break
                    }
                }
            } else { // Day is unmarked (nil)
                if foundFirstMarkedDay {
                    // An unmarked day does not break an active streak. Continue.
                }
                // If streak hasn't started, just keep looking backwards.
            }

            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prevDay
        }
        
        return streak
    }
}

struct ContentView: View {
    @StateObject var viewModel = HabitViewModel()
    @State private var newHabitName = ""
    @State private var selection = Set<UUID>()
    @State private var showingBulkDeleteConfirmation = false
    @State private var habitIDsToDelete = Set<UUID>()
    @State private var isEditing = false
    @State private var showingAddHabitSheet = false // New state for showing the sheet
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    if isEditing {
                        ForEach(viewModel.habits) { habit in
                            HStack {
                                if selection.contains(habit.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                                
                                Text(habit.name)
                                Spacer()

                                let streak = viewModel.currentStreak(for: habit)
                                let streakColor: Color = (streak == 0) ? .red : .green

                                Text("\(streak > 99 ? "99+" : "\(streak)")")
                                    .font(.caption)
                                    .frame(width: 25, height: 25)
                                    .background(
                                        Circle()
                                            .foregroundColor(streakColor)
                                    )
                                    .foregroundColor(.white)
                                    .padding(.trailing, 8)

                                let pct = viewModel.successPercentage(for: habit)
                                Text(String(format: "%.0f%%", pct))
                                    .foregroundColor(pct < 34 ? .red : (pct < 67 ? .yellow : .green))
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selection.contains(habit.id) {
                                    selection.remove(habit.id)
                                } else {
                                    selection.insert(habit.id)
                                }
                                FeedbackManager.shared.selection()
                            }
                        }
                        .onMove(perform: viewModel.moveHabits)
                    } else {
                        ForEach(viewModel.habits) { habit in
                            NavigationLink(destination: HabitDetailView(habitId: habit.id)
                                .environmentObject(viewModel)
                            ) {
                                HStack {
                                    Text(habit.name)
                                    Spacer()
                                    
                                    let streak = viewModel.currentStreak(for: habit)
                                    let streakColor: Color = (streak == 0) ? .red : .green

                                    Text("\(streak > 99 ? "99+" : "\(streak)")")
                                        .font(.caption)
                                        .frame(width: 25, height: 25)
                                        .background(
                                            Circle()
                                                .foregroundColor(streakColor)
                                        )
                                        .foregroundColor(.white)
                                        .padding(.trailing, 8)
                                    
                                    let pct = viewModel.successPercentage(for: habit)
                                    Text(String(format: "%.0f%%", pct))
                                        .foregroundColor(pct < 34 ? .red : (pct < 67 ? .yellow : .green))
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.removeHabits(at: indexSet)
                            FeedbackManager.shared.error()
                        }
                        .onMove(perform: viewModel.moveHabits)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Habit Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                        if !isEditing {
                            selection.removeAll()
                        }
                    }
                    .id(isEditing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button(role: .destructive) {
                            habitIDsToDelete = selection
                            showingBulkDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(selection.isEmpty)
                    } else {
                        Button {
                            showingAddHabitSheet = true
                        } label: {
                            Label("Add Habit", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHabitSheet) {
                NavigationView {
                    Form {
                        TextField("New Habit Name", text: $newHabitName)
                    }
                    .navigationTitle("Add New Habit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                newHabitName = ""
                                showingAddHabitSheet = false
                                hideKeyboard()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                viewModel.addHabit(name: newHabitName)
                                newHabitName = ""
                                showingAddHabitSheet = false
                                hideKeyboard()
                            }
                            .disabled(newHabitName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .confirmationDialog("Delete selected habits?", isPresented: $showingBulkDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteHabits(ids: habitIDsToDelete)
                    selection.removeAll()
                    habitIDsToDelete.removeAll()
                    FeedbackManager.shared.error()
                    DispatchQueue.main.async {
                        withAnimation {
                            isEditing = false // Exit edit mode after deletion
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    habitIDsToDelete.removeAll()
                }
            }
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct HabitDetailView: View {
    let habitId: UUID
    @EnvironmentObject var viewModel: HabitViewModel
    @State private var monthOffset: Int = 0
    
    @State private var showingRenameAlert = false
    @State private var renameText: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        return df
    }()
    
    private var weekdaySymbols: [String] {
        calendar.shortWeekdaySymbols
    }
    
    private var currentMonthYear: String {
        let now = Date()
        let target = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: target)
    }
    
    private func getCurrentMonthDates() -> [Date] {
        let now = Date()
        let target = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
        guard
            let range = calendar.range(of: .day, in: .month, for: target),
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: target))
        else {
            return []
        }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
    
    private func leadingEmptyDaysCount() -> Int {
        guard let firstDate = getCurrentMonthDates().first else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDate) // 1=Sunday,...7=Saturday
        
        // Adjust to 0-based index aligned with weekdaySymbols order
        // calendar.shortWeekdaySymbols start with Sunday at index 0, so weekday-1 is correct
        return weekday - 1
    }
    
    private var habit: Habit? {
        viewModel.habits.first(where: { $0.id == habitId })
    }

    var body: some View {
        VStack(spacing: 16) {
            if let habit = habit {
                Text(habit.name)
                    .font(.title)
                    .bold()
                    .padding(.top)
                
                Text(currentMonthYear)
                    .font(.headline)
                    .padding(.top, 4)
                
                HStack {
                    Button(action: {
                        monthOffset -= 1
                        FeedbackManager.shared.tap()
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: {
                        monthOffset += 1
                        FeedbackManager.shared.tap()
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid
                let dates = getCurrentMonthDates()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    // Leading empty spaces
                    ForEach(0..<leadingEmptyDaysCount(), id: \.self) { _ in
                        Text("")
                            .frame(height: 40)
                    }
                    
                    ForEach(dates, id: \.self) { date in
                        let dateString = dateFormatter.string(from: date)
                        let completed = viewModel.isCompleted(habitId: habit.id, dateString: dateString)
                        let color: Color = (completed == true) ? .green : ((completed == false) ? .red : .gray)

                        Text("\(calendar.component(.day, from: date))")
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .foregroundColor(color)
                            )
                            .foregroundColor(.white)
                            .overlay(
                                Circle()
                                    .stroke(Calendar.current.isDateInToday(date) ? Color.yellow : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                switch completed {
                                case nil:
                                    viewModel.markCompletion(habitId: habit.id, dateString: dateString, completed: true)
                                    FeedbackManager.shared.success()
                                case true:
                                    viewModel.markCompletion(habitId: habit.id, dateString: dateString, completed: false)
                                    FeedbackManager.shared.failure()
                                case false:
                                    viewModel.removeCompletion(habitId: habit.id, dateString: dateString)
                                    FeedbackManager.shared.tap()
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    let lifetimePct = viewModel.successPercentage(for: habit)
                    let streak = viewModel.currentStreak(for: habit)

                    Text("Current Streak: \(streak) day\(streak == 1 ? "" : "s")")
                        .font(.subheadline)
                        .bold()
                    Text(String(format: "Success (All Time): %.0f%%", lifetimePct))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                
                Spacer()
            } else {
                Text("Habit not found")
                    .foregroundColor(.secondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        if let habit = habit {
                            renameText = habit.name
                            showingRenameAlert = true
                        }
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Habit", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Habit - Enter a new name", isPresented: $showingRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let habit = habit {
                    viewModel.renameHabit(id: habit.id, newName: renameText)
                }
            }
        }
        .confirmationDialog("Delete this habit?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Habit", role: .destructive) {
                if let habit = habit {
                    viewModel.deleteHabit(id: habit.id)
                    dismiss()
                    FeedbackManager.shared.error()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .navigationTitle("Habit Details")
    }
}

#Preview {
    ContentView()
}
