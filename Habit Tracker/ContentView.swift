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
    var notes: String? = nil
    var isArchived: Bool = false
    
    init(id: UUID = UUID(), name: String, completion: [String: Bool] = [:], notes: String? = nil, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.completion = completion
        self.notes = notes
        self.isArchived = isArchived
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case completion
        case notes
        case isArchived
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        completion = try container.decodeIfPresent([String: Bool].self, forKey: .completion) ?? [:]
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(completion, forKey: .completion)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isArchived, forKey: .isArchived)
    }
}

struct NotesSheetContext: Identifiable {
    let id: UUID
    let title: String
}

struct StatsSheetContext: Identifiable {
    let id: UUID
}

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    
    private let fileManager = HabitFileManager.shared
    private var fileChangeObserver: AnyCancellable?
    
    init() {
        loadHabits()
        fileChangeObserver = NotificationCenter.default.publisher(for: HabitFileManager.fileDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadHabits()
            }
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
        habits[index] = Habit(
            id: habits[index].id,
            name: trimmed,
            completion: habits[index].completion,
            notes: habits[index].notes,
            isArchived: habits[index].isArchived
        )
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

    func moveActiveHabits(from source: IndexSet, to destination: Int) {
        var active = activeHabits
        active.move(fromOffsets: source, toOffset: destination)
        habits = active + archivedHabits
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
    
    func resetHabit(id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index] = Habit(
            id: habits[index].id,
            name: habits[index].name,
            completion: [:],
            notes: habits[index].notes,
            isArchived: habits[index].isArchived
        )
        saveHabits()
    }
    
    func updateNotes(id: UUID, notes: String) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedNotes: String? = trimmed.isEmpty ? nil : trimmed
        habits[index] = Habit(
            id: habits[index].id,
            name: habits[index].name,
            completion: habits[index].completion,
            notes: updatedNotes,
            isArchived: habits[index].isArchived
        )
        saveHabits()
    }
    
    func isCompleted(habitId: UUID, dateString: String) -> Bool? {
        if let habit = habits.first(where: { $0.id == habitId }) {
            return habit.completion[dateString]
        }
        return nil
    }
    
    func loadHabits() {
        habits = fileManager.loadHabits()
    }
    
    func saveHabits() {
        fileManager.saveHabits(habits)
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
    
    func totalSuccessfulDays(for habit: Habit) -> Int {
        habit.completion.values.filter { $0 == true }.count
    }
    
    func allTimeStreak(for habit: Habit) -> Int {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        
        let markedDates: [(Date, Bool)] = habit.completion.compactMap { key, value in
            guard let date = df.date(from: key) else { return nil }
            return (date, value)
        }
        .sorted { $0.0 < $1.0 }
        
        var maxStreak = 0
        var current = 0
        
        for (_, value) in markedDates {
            if value {
                current += 1
                if current > maxStreak {
                    maxStreak = current
                }
            } else {
                current = 0
            }
        }
        
        return maxStreak
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
    
    func dateString(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        return df.string(from: date)
    }
    
    func weekDates(for weekOffset: Int) -> [Date] {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: target) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }
    
    func weekSuccessPercentage(weekOffset: Int) -> Double {
        let dateStrings = weekDates(for: weekOffset).map { dateString(for: $0) }
        guard !dateStrings.isEmpty else { return 0 }
        var total = 0
        var success = 0
        
        for habit in activeHabits {
            for dateString in dateStrings {
                if let value = habit.completion[dateString] {
                    total += 1
                    if value {
                        success += 1
                    }
                }
            }
        }
        
        guard total > 0 else { return 0 }
        return (Double(success) / Double(total)) * 100.0
    }
    
    func overallSuccessPercentage() -> Double {
        var total = 0
        var success = 0
        
        for habit in activeHabits {
            for value in habit.completion.values {
                total += 1
                if value {
                    success += 1
                }
            }
        }
        
        guard total > 0 else { return 0 }
        return (Double(success) / Double(total)) * 100.0
    }
    
    var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }
    
    var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }
    
    func archiveHabit(id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].isArchived = true
        habits = activeHabits + archivedHabits
        saveHabits()
    }
    
    func restoreHabit(id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].isArchived = false
        habits = activeHabits + archivedHabits
        saveHabits()
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
    @State private var showingSwipeDeleteConfirmation = false
    @State private var pendingDeleteHabitId: UUID?
    @State private var showingRetryConfirmation = false
    @State private var pendingRetryHabitId: UUID?
    @State private var showingArchiveConfirmation = false
    @State private var pendingArchiveHabitId: UUID?
    @State private var showingRestoreConfirmation = false
    @State private var pendingRestoreHabitId: UUID?
    @State private var showingRenameAlert = false
    @State private var renameHabitId: UUID?
    @State private var renameText = ""
    @State private var notesText = ""
    @State private var notesSheet: NotesSheetContext?
    @State private var showingBirdsEyeSheet = false
    @State private var hasEditChanges = false
    @State private var showingArchived = false
    
    var body: some View {
        rootView
    }
    
    private var rootView: some View {
        NavigationView {
            mainContent
        }
        .sheet(isPresented: $showingAddHabitSheet) {
            AddHabitView(viewModel: viewModel,
                         newHabitName: $newHabitName,
                         isPresented: $showingAddHabitSheet)
        }
        .sheet(isPresented: $showingBirdsEyeSheet) {
            BirdsEyeView()
                .environmentObject(viewModel)
        }
        .sheet(item: $notesSheet) { sheet in
            NotesEditorSheet(
                title: sheet.title,
                notesText: $notesText,
                onCancel: {
                    notesText = ""
                    notesSheet = nil
                },
                onSave: {
                    viewModel.updateNotes(id: sheet.id, notes: notesText)
                    notesText = ""
                    notesSheet = nil
                }
            )
        }
        .alert("Rename Habit - Enter a new name", isPresented: $showingRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameHabitId = nil
            }
            Button("Save") {
                if let habitId = renameHabitId {
                    viewModel.renameHabit(id: habitId, newName: renameText)
                }
                renameHabitId = nil
            }
        }
        .alert("Delete this habit?", isPresented: $showingSwipeDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let habitId = pendingDeleteHabitId {
                    viewModel.deleteHabit(id: habitId)
                    FeedbackManager.shared.error()
                }
                pendingDeleteHabitId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteHabitId = nil
            }
        }
        .alert("Retry this habit? This resets its progress.", isPresented: $showingRetryConfirmation) {
            Button("Retry") {
                if let habitId = pendingRetryHabitId {
                    viewModel.resetHabit(id: habitId)
                    FeedbackManager.shared.tap()
                }
                pendingRetryHabitId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRetryHabitId = nil
            }
        }
        .alert("Archive this habit?", isPresented: $showingArchiveConfirmation) {
            Button("Archive") {
                if let habitId = pendingArchiveHabitId {
                    viewModel.archiveHabit(id: habitId)
                }
                pendingArchiveHabitId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingArchiveHabitId = nil
            }
        }
        .alert("Restore this habit?", isPresented: $showingRestoreConfirmation) {
            Button("Restore") {
                if let habitId = pendingRestoreHabitId {
                    viewModel.restoreHabit(id: habitId)
                }
                pendingRestoreHabitId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRestoreHabitId = nil
            }
        }
        .alert("Delete selected habits?", isPresented: $showingBulkDeleteConfirmation) {
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
            Button(role: .cancel) {
                habitIDsToDelete.removeAll()
            }
        }
    }
    
    private var mainContent: some View {
        VStack {
            habitList
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(editButtonTitle) {
                    isEditing.toggle()
                    if isEditing {
                        hasEditChanges = false
                    } else {
                        selection.removeAll()
                        hasEditChanges = false
                    }
                }
                .disabled(viewModel.activeHabits.isEmpty)
                .id(isEditing)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingBirdsEyeSheet = true
                } label: {
                    Image(systemName: "bird")
                }
                .disabled(isEditing)
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
    }
    
    private var editButtonTitle: String {
        if isEditing {
            return hasEditChanges ? "Done" : "Cancel"
        }
        return "Edit"
    }
    
    private var habitList: some View {
        List {
            habitListRows
        }
        .listStyle(PlainListStyle())
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
    }
    
    @ViewBuilder
    private var habitListRows: some View {
        if isEditing {
            ForEach(viewModel.activeHabits) { habit in
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
            .onMove { source, destination in
                viewModel.moveActiveHabits(from: source, to: destination)
                hasEditChanges = true
            }
        } else {
            ForEach(viewModel.activeHabits) { habit in
                NavigationLink(destination: HabitDetailView(habitId: habit.id)
                    .environmentObject(viewModel)
                ) {
                    MainHabitRow(viewModel: viewModel, habit: habit) {
                        notesText = habit.notes ?? ""
                        notesSheet = NotesSheetContext(id: habit.id, title: habit.name)
                    }
                }
                .contextMenu {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        pendingRetryHabitId = habit.id
                        showingRetryConfirmation = true
                    }
                    Button("Archive", systemImage: "archivebox") {
                        pendingArchiveHabitId = habit.id
                        showingArchiveConfirmation = true
                    }
                    Button("Rename", systemImage: "pencil") {
                        renameHabitId = habit.id
                        renameText = habit.name
                        showingRenameAlert = true
                    }
                    Button(role: .destructive) {
                        pendingDeleteHabitId = habit.id
                        showingSwipeDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        pendingDeleteHabitId = habit.id
                        showingSwipeDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    
                    Button {
                        renameHabitId = habit.id
                        renameText = habit.name
                        showingRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        pendingRetryHabitId = habit.id
                        showingRetryConfirmation = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(.orange)
                    Button {
                        pendingArchiveHabitId = habit.id
                        showingArchiveConfirmation = true
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .tint(.green)
                }
            }
            
            if !viewModel.archivedHabits.isEmpty {
                DisclosureGroup(isExpanded: $showingArchived) {
                    ForEach(viewModel.archivedHabits) { habit in
                        HStack {
                            Text(habit.name)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Restore") {
                                pendingRestoreHabitId = habit.id
                                showingRestoreConfirmation = true
                            }
                            .buttonStyle(.borderless)
                        }
                        .contextMenu {
                            Button("Restore", systemImage: "arrow.uturn.backward") {
                                pendingRestoreHabitId = habit.id
                                showingRestoreConfirmation = true
                            }
                            Button(role: .destructive) {
                                pendingDeleteHabitId = habit.id
                                showingSwipeDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                pendingRestoreHabitId = habit.id
                                showingRestoreConfirmation = true
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteHabitId = habit.id
                                showingSwipeDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                } label: {
                    Text("Archived")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
}

struct BirdsEyeView: View {
    @EnvironmentObject var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var weekOffset = 0
    @State private var notesText = ""
    @State private var notesSheet: NotesSheetContext?
    @State private var statsSheet: StatsSheetContext?
    
    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let isCompactWidth = proxy.size.width < 360
                let dotSize: CGFloat = isCompactWidth ? 20 : 25
                
                VStack(spacing: 12) {
                    let weekPct = viewModel.weekSuccessPercentage(weekOffset: weekOffset)
                    let overallPct = viewModel.overallSuccessPercentage()
                    
                    VStack(spacing: 4) {
                        Text(String(format: "All-Time Success: %.0f%%", overallPct))
                            .font(.headline)
                            .foregroundColor(overallPct < 34 ? .red : (overallPct < 67 ? .yellow : .green))
                        Text(String(format: "Week Success: %.0f%%", weekPct))
                            .font(.subheadline)
                            .foregroundColor(weekPct < 34 ? .red : (weekPct < 67 ? .yellow : .green))
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            weekOffset -= 1
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        
                        Text(weekRangeTitle(weekOffset: weekOffset))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            weekOffset += 1
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    WeekdayHeaderRow(weekDates: viewModel.weekDates(for: weekOffset), dotSize: dotSize)
                        .padding(.horizontal)
                    
                    List {
                        ForEach(viewModel.activeHabits) { habit in
                            BirdsEyeHabitRow(
                                habit: habit,
                                weekDates: viewModel.weekDates(for: weekOffset),
                                dotSize: dotSize,
                                isCompactWidth: isCompactWidth
                            ) {
                                statsSheet = StatsSheetContext(id: habit.id)
                            } onShowNotes: {
                                notesText = habit.notes ?? ""
                                notesSheet = NotesSheetContext(id: habit.id, title: habit.name)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Bird's-Eye")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $statsSheet) { sheet in
            HabitStatsSheet(habitId: sheet.id)
                .environmentObject(viewModel)
        }
        .sheet(item: $notesSheet) { sheet in
            NotesEditorSheet(
                title: sheet.title,
                notesText: $notesText,
                onCancel: {
                    notesText = ""
                    notesSheet = nil
                },
                onSave: {
                    viewModel.updateNotes(id: sheet.id, notes: notesText)
                    notesText = ""
                    notesSheet = nil
                }
            )
        }
    }
    
    private func weekRangeTitle(weekOffset: Int) -> String {
        let dates = viewModel.weekDates(for: weekOffset)
        guard let start = dates.first, let end = dates.last else { return "Week" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        return "\(startText)–\(endText)"
    }
}

struct WeekdayHeaderRow: View {
    let weekDates: [Date]
    let dotSize: CGFloat
    
    var body: some View {
        let symbols = orderedWeekdaySymbols
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Habit")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 6) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, _ in
                    Text(symbols.indices.contains(index) ? symbols[index] : "")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .dynamicTypeSize(.xSmall ... .large)
                        .frame(width: dotSize)
                }
            }
        }
    }
    
    private var orderedWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex..<symbols.count] + symbols[0..<startIndex])
    }
}

struct BirdsEyeHabitRow: View {
    @EnvironmentObject var viewModel: HabitViewModel
    let habit: Habit
    let weekDates: [Date]
    let dotSize: CGFloat
    let isCompactWidth: Bool
    let onShowStats: () -> Void
    let onShowNotes: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(habit.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isCompactWidth {
                    Menu {
                        Button {
                            onShowStats()
                        } label: {
                            Label("Statistics", systemImage: "chart.bar")
                        }
                        Button {
                            onShowNotes()
                        } label: {
                            Label("Notes", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        onShowStats()
                    } label: {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                    
                    Button {
                        onShowNotes()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            WeekDotsRow(habit: habit, weekDates: weekDates, dotSize: dotSize)
        }
    }
}

struct WeekDotsRow: View {
    @EnvironmentObject var viewModel: HabitViewModel
    let habit: Habit
    let weekDates: [Date]
    let dotSize: CGFloat
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                dotView(for: date)
            }
        }
    }
    
    private func dotView(for date: Date) -> some View {
        let dateString = viewModel.dateString(for: date)
        let completed = viewModel.isCompleted(habitId: habit.id, dateString: dateString)
        let color: Color = (completed == true) ? .green : ((completed == false) ? .red : .gray)
        
        return Text("\(Calendar.current.component(.day, from: date))")
            .font(.caption2)
            .monospacedDigit()
            .dynamicTypeSize(.xSmall ... .large)
            .frame(width: dotSize, height: dotSize)
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

struct HabitStatsSheet: View {
    let habitId: UUID
    @EnvironmentObject var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var habit: Habit? {
        viewModel.habits.first(where: { $0.id == habitId })
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 10) {
                if let habit = habit {
                    let lifetimePct = viewModel.successPercentage(for: habit)
                    let streak = viewModel.currentStreak(for: habit)
                    Text(habit.name)
                        .font(.title3)
                        .bold()
                        .padding(.bottom, 6)
                    Text("Current Streak: \(streak) day\(streak == 1 ? "" : "s")")
                        .font(.subheadline)
                        .bold()
                    Text(String(format: "Success (All Time): %.0f%%", lifetimePct))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Total Successful Days: \(viewModel.totalSuccessfulDays(for: habit))")
                        .font(.subheadline)
                    Text("All-Time Streak: \(viewModel.allTimeStreak(for: habit)) days")
                        .font(.subheadline)
                } else {
                    Text("Habit not found")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MainHabitRow: View {
    @ObservedObject var viewModel: HabitViewModel
    let habit: Habit
    let onShowNotes: () -> Void
    
    var body: some View {
        HStack {
            Text(habit.name)
            
            Button {
                onShowNotes()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            let streak = viewModel.currentStreak(for: habit)
            let streakColor: Color = (streak == 0) ? .red : .green
            let hasMarks = !habit.completion.isEmpty
            let streakText = hasMarks ? (streak > 99 ? "99+" : "\(streak)") : "–"
            let streakFill: Color = hasMarks ? streakColor : .gray

            Text(streakText)
                .font(.caption)
                .frame(width: 25, height: 25)
                .background(
                    Circle()
                        .foregroundColor(streakFill)
                )
                .foregroundColor(.white)
            
            let pct = viewModel.successPercentage(for: habit)
            let pctText = hasMarks ? String(format: "%.0f%%", pct) : "–"
            let pctColor: Color = hasMarks ? (pct < 34 ? .red : (pct < 67 ? .yellow : .green)) : .gray
            Text(pctText)
                .foregroundColor(pctColor)
                .frame(width: 50, alignment: hasMarks ? .trailing : .center)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingDeleteConfirmation = false
    @State private var showingRetryConfirmation = false
    @State private var showingArchiveConfirmation = false
    @State private var showingNotesSheet = false
    @State private var notesText = ""
    @State private var showingStats = false
    
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

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(calendarDotSize), spacing: calendarGridSpacing, alignment: .center), count: 7)
    }

    private var calendarGridSpacing: CGFloat { 10 }
    private var calendarDotSize: CGFloat { 36 }
    private var calendarGridWidth: CGFloat {
        (calendarDotSize * 7) + (calendarGridSpacing * 6)
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
        ScrollView {
            VStack(spacing: 16) {
                if let habit = habit {
                    detailContent(for: habit, isCompactWidth: isCompactWidth)
                } else {
                    Text("Habit not found")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 600, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        showingRetryConfirmation = true
                    }
                    Button("Archive", systemImage: "archivebox") {
                        showingArchiveConfirmation = true
                    }
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
        .alert("Retry this habit? This resets its progress.", isPresented: $showingRetryConfirmation) {
            Button("Retry") {
                viewModel.resetHabit(id: habitId)
                FeedbackManager.shared.tap()
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Archive this habit?", isPresented: $showingArchiveConfirmation) {
            Button("Archive") {
                viewModel.archiveHabit(id: habitId)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
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
        .sheet(isPresented: $showingNotesSheet) {
            NotesEditorSheet(
                title: habit?.name ?? "",
                notesText: $notesText,
                onCancel: {
                    showingNotesSheet = false
                },
                onSave: {
                    viewModel.updateNotes(id: habitId, notes: notesText)
                    showingNotesSheet = false
                }
            )
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailContent(for habit: Habit, isCompactWidth: Bool) -> some View {
        habitHeader(for: habit, isCompactWidth: isCompactWidth)
        Text(currentMonthYear)
            .font(.headline)
            .padding(.top, 4)
        monthNavigation
        weekdayHeader
        calendarGrid(for: habit)
        Spacer(minLength: 12)
        statsSection(for: habit)
    }

    private func habitHeader(for habit: Habit, isCompactWidth: Bool) -> some View {
        HStack(spacing: 8) {
            Text(habit.name)
                .font(.title)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .dynamicTypeSize(.xSmall ... .xxLarge)
            Button {
                notesText = habit.notes ?? ""
                showingNotesSheet = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.top, headerTopPadding(isCompactWidth: isCompactWidth))
    }

    private func headerTopPadding(isCompactWidth: Bool) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize || isCompactWidth {
            return 25
        }
        return 75
    }

    private var isCompactWidth: Bool {
        screenWidth > 0 ? screenWidth < 360 : true
    }

    private var screenWidth: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 0
    }

    private var monthNavigation: some View {
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
    }

    private var weekdayHeader: some View {
        HStack {
            Spacer(minLength: 0)
            LazyVGrid(columns: calendarColumns, spacing: calendarGridSpacing) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .dynamicTypeSize(.xSmall ... .large)
                        .frame(width: calendarDotSize, alignment: .center)
                }
            }
            .frame(width: calendarGridWidth)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func calendarGrid(for habit: Habit) -> some View {
        let dates = getCurrentMonthDates()
        HStack {
            Spacer(minLength: 0)
            LazyVGrid(columns: calendarColumns, spacing: calendarGridSpacing) {
                ForEach(0..<leadingEmptyDaysCount(), id: \.self) { _ in
                    Color.clear
                        .frame(width: calendarDotSize, height: calendarDotSize)
                }
                ForEach(dates, id: \.self) { date in
                    let dateString = dateFormatter.string(from: date)
                    let completed = viewModel.isCompleted(habitId: habit.id, dateString: dateString)
                    let color: Color = (completed == true) ? .green : ((completed == false) ? .red : .gray)

                    Text("\(calendar.component(.day, from: date))")
                        .frame(width: calendarDotSize, height: calendarDotSize)
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
            .frame(width: calendarGridWidth)
            Spacer(minLength: 0)
        }
    }

    private func statsSection(for habit: Habit) -> some View {
        VStack(alignment: .center, spacing: 6) {
            let lifetimePct = viewModel.successPercentage(for: habit)
            let streak = viewModel.currentStreak(for: habit)

            VStack(alignment: .center, spacing: 6) {
                Text("Current Streak: \(streak) day\(streak == 1 ? "" : "s")")
                    .font(.subheadline)
                    .bold()
                Text(String(format: "Success (All Time): %.0f%%", lifetimePct))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if showingStats {
                    Text("Total Successful Days: \(viewModel.totalSuccessfulDays(for: habit))")
                        .font(.subheadline)
                    Text("All-Time Streak: \(viewModel.allTimeStreak(for: habit)) days")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingStats.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(showingStats ? 180 : 0))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

struct NotesEditorSheet: View {
    let title: String
    @Binding var notesText: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var initialText = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 10) {
                if !title.isEmpty {
                    Text(title)
                        .font(.title3)
                        .bold()
                        .padding(.horizontal)
                }
                TextEditor(text: $notesText)
                    .padding()
                    .onAppear {
                        initialText = notesText
                    }
                Spacer(minLength: 0)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(notesText == initialText)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
