//
//  ContentView.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 11/25/25.
// © Blustar Software. All rights reserved.
//

import SwiftUI
import Combine

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    var completion: [String: Bool] = [:] // key: date string (e.g., "2025-11-25")
    var notes: String? = nil
    var isArchived: Bool = false
    var createdAt: Date = Date()
    
    init(id: UUID = UUID(), name: String, completion: [String: Bool] = [:], notes: String? = nil, isArchived: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.completion = completion
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case completion
        case notes
        case isArchived
        case createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        completion = try container.decodeIfPresent([String: Bool].self, forKey: .completion) ?? [:]
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(completion, forKey: .completion)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

enum ReportType: String, Codable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case catchUp = "Catch-up"
}

struct ProgressReport: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ReportType
    let dateRange: String
    let overallSuccess: Double
    let generatedAt: Date
    var isRead: Bool
    let topHabits: [String] // Names of most successful habits
    let focusHabits: [String] // Names of least successful habits
    
    init(id: UUID = UUID(), type: ReportType, dateRange: String, overallSuccess: Double, generatedAt: Date = Date(), isRead: Bool = false, topHabits: [String], focusHabits: [String]) {
        self.id = id
        self.type = type
        self.dateRange = dateRange
        self.overallSuccess = overallSuccess
        self.generatedAt = generatedAt
        self.isRead = isRead
        self.topHabits = topHabits
        self.focusHabits = focusHabits
    }
}

struct HabitData: Codable {
    var habits: [Habit]
    var reports: [ProgressReport]
    
    init(habits: [Habit] = [], reports: [ProgressReport] = []) {
        self.habits = habits
        self.reports = reports
    }
}

struct NotesSheetContext: Identifiable {
    let id: UUID
    let title: String
    let isArchived: Bool
}

struct StatsSheetContext: Identifiable {
    let id: UUID
}

class HabitViewModel: ObservableObject {
    enum SortOrder: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case successRate = "Sorted"
        var id: String { rawValue }
    }
    
    enum StatMode: String, CaseIterable, Identifiable {
        case allTime = "All-Time"
        case monthly = "Monthly"
        var id: String { rawValue }
    }
    
    @Published var habits: [Habit] = []
    @Published var reports: [ProgressReport] = []
    @Published var sortOrder: SortOrder {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: "HabitSortOrder")
        }
    }
    @Published var statMode: StatMode {
        didSet {
            UserDefaults.standard.set(statMode.rawValue, forKey: "HabitStatMode")
        }
    }
    
    private let fileManager = HabitFileManager.shared
    private var fileChangeObserver: AnyCancellable?
    
    init() {
        let savedSort = UserDefaults.standard.string(forKey: "HabitSortOrder") ?? SortOrder.manual.rawValue
        self.sortOrder = SortOrder(rawValue: savedSort) ?? .manual
        
        let savedStat = UserDefaults.standard.string(forKey: "HabitStatMode") ?? StatMode.allTime.rawValue
        self.statMode = StatMode(rawValue: savedStat) ?? .allTime
        
        loadHabits()
        fileChangeObserver = NotificationCenter.default.publisher(for: HabitFileManager.fileDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadHabits()
            }
            
        // Check for reports on init
        checkAndGenerateReports()
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
            isArchived: habits[index].isArchived,
            createdAt: habits[index].createdAt
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
            isArchived: habits[index].isArchived,
            createdAt: habits[index].createdAt
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
            isArchived: habits[index].isArchived,
            createdAt: habits[index].createdAt
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
        let data = fileManager.loadHabitData()
        self.habits = data.habits
        self.reports = data.reports
    }
    
    func saveHabits() {
        fileManager.saveHabitData(HabitData(habits: habits, reports: reports))
    }

    func markReportAsRead(id: UUID) {
        if let index = reports.firstIndex(where: { $0.id == id }) {
            reports[index].isRead = true
            saveHabits()
        }
    }

    func deleteReport(at offsets: IndexSet) {
        reports.remove(atOffsets: offsets)
        saveHabits()
    }
    
    // MARK: - Report Generation Logic
    
    private func checkAndGenerateReports() {
        let now = Date()
        let calendar = Calendar.current
        
        // 1. Identify the baseline date
        // If no reports exist, we consider 1 month ago as the baseline.
        let lastReportDate = reports.map { $0.generatedAt }.max() ?? calendar.date(byAdding: .month, value: -1, to: now)!
        
        var generatedAny = false
        var checkDate = calendar.startOfDay(for: lastReportDate)
        let endDay = calendar.startOfDay(for: now)
        
        // Step forward day by day from last report date to today
        while checkDate < endDay {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = nextDay
            
            let components = calendar.dateComponents([.weekday, .day], from: checkDate)
            
            // Monthly check: If checkDate is the 1st of a month
            if components.day == 1 {
                let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: checkDate)!
                let prevMonthComps = calendar.dateComponents([.year, .month], from: prevMonthDate)
                if generateMonthlyReport(for: prevMonthComps.month!, year: prevMonthComps.year!) {
                    generatedAny = true
                }
            }
            
            // Weekly check: If checkDate is a Monday
            if components.weekday == 2 {
                let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: checkDate)!
                if generateWeeklyReport(from: startOfLastWeek, to: checkDate) {
                    generatedAny = true
                }
            }
        }
        
        if generatedAny {
            saveHabits()
        }
    }
    
    private func generateWeeklyReport(from start: Date, to end: Date) -> Bool {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let rangeString = "\(df.string(from: start)) – \(df.string(from: end))"
        return createReport(type: .weekly, start: start, end: end, rangeString: rangeString)
    }
    
    private func generateMonthlyReport(for month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else { return false }
        
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        let rangeString = df.string(from: startOfMonth)
        
        return createReport(type: .monthly, start: startOfMonth, end: endOfMonth, rangeString: rangeString)
    }
    
    private func createReport(type: ReportType, start: Date, end: Date, rangeString: String) -> Bool {
        let habitsToAnalyze = habits.filter { !$0.isArchived || $0.completion.values.contains(true) }
        guard !habitsToAnalyze.isEmpty else { return false }
        
        var totalMarks = 0
        var successMarks = 0
        
        struct HabitStat {
            let name: String
            let pct: Double
        }
        var habitStats: [HabitStat] = []
        
        for habit in habitsToAnalyze {
            let filtered = filterCompletion(habit.completion, from: start, to: end)
            let total = filtered.count
            if total > 0 {
                let success = filtered.filter { $0.value == true }.count
                totalMarks += total
                successMarks += success
                habitStats.append(HabitStat(name: habit.name, pct: Double(success) / Double(total)))
            }
        }
        
        guard totalMarks > 0 else { return false }
        
        let overall = (Double(successMarks) / Double(totalMarks)) * 100.0
        let sorted = habitStats.sorted { $0.pct > $1.pct }
        
        let top = Array(sorted.prefix(3)).map { $0.name }
        let focus = Array(sorted.suffix(3).reversed()).filter { stat in !top.contains(stat.name) }.map { $0.name }
        
        let report = ProgressReport(
            type: type,
            dateRange: rangeString,
            overallSuccess: overall,
            topHabits: top,
            focusHabits: focus
        )
        
        reports.insert(report, at: 0)
        return true
    }
    
    private func filterCompletion(_ completion: [String: Bool], from start: Date, to end: Date) -> [String: Bool] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        
        return completion.filter { key, _ in
            guard let date = df.date(from: key) else { return false }
            let day = calendar.startOfDay(for: date)
            return day >= startDay && day <= endDay
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
    
    func hasMarks(for habit: Habit, year: Int, month: Int) -> Bool {
        return habit.completion.keys.contains { key in
            let comps = key.split(separator: "-")
            guard comps.count == 3,
                  let y = Int(comps[0]),
                  let m = Int(comps[1]) else { return false }
            return y == year && m == month
        }
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

    func monthlySuccessPercentage(monthOffset: Int) -> Double {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: target)
        guard let year = comps.year, let month = comps.month else { return 0 }
        
        var total = 0
        var success = 0
        
        for habit in activeHabits {
            let filtered = habit.completion.filter { (key, value) in
                let comps = key.split(separator: "-")
                guard comps.count == 3,
                      let y = Int(comps[0]),
                      let m = Int(comps[1]) else { return false }
                return y == year && m == month
            }
            for value in filtered.values {
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
        let list = habits.filter { !$0.isArchived }
        return sortHabits(list)
    }
    
    var archivedHabits: [Habit] {
        let list = habits.filter { $0.isArchived }
        return sortHabits(list)
    }

    private func sortHabits(_ list: [Habit]) -> [Habit] {
        switch sortOrder {
        case .manual:
            return list
        case .successRate:
            let now = Date()
            let calendar = Calendar.current
            
            return list.sorted { h1, h2 in
                let p1: Double
                let p2: Double
                
                if self.statMode == .allTime {
                    p1 = self.successPercentage(for: h1)
                    p2 = self.successPercentage(for: h2)
                } else {
                    let year = calendar.component(.year, from: now)
                    let month = calendar.component(.month, from: now)
                    p1 = self.successPercentage(for: h1, year: year, month: month)
                    p2 = self.successPercentage(for: h2, year: year, month: month)
                }
                
                if p1 != p2 {
                    return p1 > p2
                }
                
                // Tie-breaker
                if self.statMode == .monthly {
                    // Previous Month tie-breaker for monthly mode
                    let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
                    let prevYear = calendar.component(.year, from: prevMonthDate)
                    let prevMonth = calendar.component(.month, from: prevMonthDate)
                    let prevP1 = self.successPercentage(for: h1, year: prevYear, month: prevMonth)
                    let prevP2 = self.successPercentage(for: h2, year: prevYear, month: prevMonth)
                    if prevP1 != prevP2 {
                        return prevP1 > prevP2
                    }
                }
                
                // Final fallback
                return h1.createdAt < h2.createdAt
            }
        }
    }
    
    func archiveHabit(id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].isArchived = true
        habits = habits.filter { !$0.isArchived } + habits.filter { $0.isArchived } // Keep relative manual order if possible
        saveHabits()
    }

    func archiveHabits(ids: Set<UUID>) {
        for id in ids {
            if let index = habits.firstIndex(where: { $0.id == id }) {
                habits[index].isArchived = true
            }
        }
        habits = habits.filter { !$0.isArchived } + habits.filter { $0.isArchived }
        saveHabits()
    }
    
    func restoreHabit(id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].isArchived = false
        habits = habits.filter { !$0.isArchived } + habits.filter { $0.isArchived }
        saveHabits()
    }

    func restoreHabits(ids: Set<UUID>) {
        for id in ids {
            if let index = habits.firstIndex(where: { $0.id == id }) {
                habits[index].isArchived = false
            }
        }
        habits = habits.filter { !$0.isArchived } + habits.filter { $0.isArchived }
        saveHabits()
    }
}

struct ContentView: View {
    enum HabitFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case archived = "Archived"
        case all = "All"
        
        var id: String { rawValue }
    }
    
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
    @State private var selectedFilter: HabitFilter = .active
    @State private var showingResetSelectionConfirmation = false
    @State private var showingBulkArchiveConfirmation = false
    @State private var showingBulkRestoreConfirmation = false
    @State private var showingReportsSheet = false
    
    private var activeSelectedCount: Int {
        viewModel.habits.filter { selection.contains($0.id) && !$0.isArchived }.count
    }
    
    private var archivedSelectedCount: Int {
        viewModel.habits.filter { selection.contains($0.id) && $0.isArchived }.count
    }
    
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
        .sheet(isPresented: $showingReportsSheet) {
            ReportsListView()
                .environmentObject(viewModel)
        }
        .sheet(item: $notesSheet) { sheet in
            NotesEditorSheet(
                title: sheet.title,
                isReadOnly: sheet.isArchived,
                notesText: $notesText,
                onCancel: {
                    notesSheet = nil
                },
                onSave: {
                    viewModel.updateNotes(id: sheet.id, notes: notesText)
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
        .alert("Reset selected habits?", isPresented: $showingResetSelectionConfirmation) {
            Button("Reset", role: .destructive) {
                for id in selection {
                    viewModel.resetHabit(id: id)
                }
                FeedbackManager.shared.tap()
                selection.removeAll()
                withAnimation {
                    isEditing = false
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Archive \(activeSelectedCount) active habit\(activeSelectedCount == 1 ? "" : "s")?", isPresented: $showingBulkArchiveConfirmation) {
            Button("Archive") {
                let activeIds = Set(viewModel.habits.filter { selection.contains($0.id) && !$0.isArchived }.map { $0.id })
                viewModel.archiveHabits(ids: activeIds)
                selection.removeAll()
                withAnimation {
                    isEditing = false
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Restore \(archivedSelectedCount) archived habit\(archivedSelectedCount == 1 ? "" : "s")?", isPresented: $showingBulkRestoreConfirmation) {
            Button("Restore") {
                let archivedIds = Set(viewModel.habits.filter { selection.contains($0.id) && $0.isArchived }.map { $0.id })
                viewModel.restoreHabits(ids: archivedIds)
                selection.removeAll()
                withAnimation {
                    isEditing = false
                }
            }
            Button("Cancel", role: .cancel) { }
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
        VStack(spacing: 8) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(HabitFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 6)
            
            habitList
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if isEditing {
                    let allSelected = !filteredHabits.isEmpty && selection.count == filteredHabits.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        if allSelected {
                            selection.removeAll()
                        } else {
                            selection = Set(filteredHabits.map { $0.id })
                        }
                    }
                    .disabled(filteredHabits.isEmpty)
                }
                
                Button(editButtonTitle) {
                    isEditing.toggle()
                    if isEditing {
                        hasEditChanges = false
                    } else {
                        selection.removeAll()
                        hasEditChanges = false
                    }
                }
                .disabled(filteredHabits.isEmpty)
                .id(isEditing)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isEditing {
                    Menu {
                        Button {
                            showingResetSelectionConfirmation = true
                        } label: {
                            Label("Reset Selection", systemImage: "arrow.clockwise")
                        }
                        
                        let selectedHabits = viewModel.habits.filter { selection.contains($0.id) }
                        let hasActiveInSelection = selectedHabits.contains(where: { !$0.isArchived })
                        let hasArchivedInSelection = selectedHabits.contains(where: { $0.isArchived })
                        
                        if hasActiveInSelection {
                            Button {
                                showingBulkArchiveConfirmation = true
                            } label: {
                                Label("Archive \(activeSelectedCount) Active", systemImage: "archivebox")
                            }
                        }
                        
                        if hasArchivedInSelection {
                            Button {
                                showingBulkRestoreConfirmation = true
                            } label: {
                                Label("Restore \(archivedSelectedCount) Archived", systemImage: "arrow.uturn.backward")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            habitIDsToDelete = selection
                            showingBulkDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(selection.isEmpty)
                } else {
                    Button {
                        showingReportsSheet = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "doc.text.magnifyingglass")
                            if viewModel.reports.contains(where: { !$0.isRead }) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }

                    Button {
                        showingBirdsEyeSheet = true
                    } label: {
                        Image(systemName: "bird")
                    }

                    Menu {
                        Section("SORT BY") {
                            Button {
                                viewModel.sortOrder = .manual
                            } label: {
                                Label("Manual Order", systemImage: viewModel.sortOrder == .manual ? "checkmark.circle.fill" : "hand.tap")
                            }
                            
                            Button {
                                viewModel.sortOrder = .successRate
                            } label: {
                                Label("Success Rate", systemImage: viewModel.sortOrder == .successRate ? "checkmark.circle.fill" : "arrow.up.arrow.down")
                            }
                        }
                        
                        Section("STATISTICS MODE") {
                            Button {
                                viewModel.statMode = .allTime
                            } label: {
                                Label("All-Time", systemImage: viewModel.statMode == .allTime ? "checkmark.circle.fill" : "infinity")
                            }
                            
                            Button {
                                viewModel.statMode = .monthly
                            } label: {
                                Label("Monthly", systemImage: viewModel.statMode == .monthly ? "checkmark.circle.fill" : "calendar")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    
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
            ForEach(filteredHabits) { habit in
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
                if viewModel.sortOrder == .manual && selectedFilter == .active {
                    viewModel.moveActiveHabits(from: source, to: destination)
                    hasEditChanges = true
                }
            }
        } else {            ForEach(filteredHabits) { habit in
                NavigationLink(destination: HabitDetailView(habitId: habit.id)
                    .environmentObject(viewModel)
                ) {
                    MainHabitRow(viewModel: viewModel, habit: habit) {
                        notesText = habit.notes ?? ""
                        notesSheet = NotesSheetContext(id: habit.id, title: habit.name, isArchived: habit.isArchived)
                    }
                }
                .contextMenu {
                    if habit.isArchived {
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
                    } else {
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
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !habit.isArchived {
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
                    } else {
                        Button(role: .destructive) {
                            pendingDeleteHabitId = habit.id
                            showingSwipeDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if habit.isArchived {
                        Button {
                            pendingRestoreHabitId = habit.id
                            showingRestoreConfirmation = true
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    } else {
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
            }
        }
    }

    private var filteredHabits: [Habit] {
        switch selectedFilter {
        case .active:
            return viewModel.activeHabits
        case .archived:
            return viewModel.archivedHabits
        case .all:
            return viewModel.activeHabits + viewModel.archivedHabits
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
    @State private var navigationPath: [UUID] = []
    @State private var showingRetryConfirmation = false
    @State private var pendingRetryHabitId: UUID?
    @State private var showingArchiveConfirmation = false
    @State private var pendingArchiveHabitId: UUID?
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteHabitId: UUID?
    @State private var showingRenameAlert = false
    @State private var renameHabitId: UUID?
    @State private var renameText = ""
    @State private var stableHabits: [Habit] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                let isCompactWidth = proxy.size.width < 360
                let dotSize: CGFloat = isCompactWidth ? 20 : 25
                
                VStack(spacing: 12) {
                    let weekPct = viewModel.weekSuccessPercentage(weekOffset: weekOffset)
                    let monthPct = viewModel.monthlySuccessPercentage(monthOffset: 0) // Current month
                    let overallPct = viewModel.overallSuccessPercentage()

                    VStack(spacing: 4) {
                        Text(String(format: "All-Time Success: %.0f%%", overallPct))
                            .font(.headline)
                            .foregroundColor(overallPct < 34 ? .red : (overallPct < 67 ? .yellow : .green))
                        Text(String(format: "Month Success: %.0f%%", monthPct))
                            .font(.subheadline)
                            .foregroundColor(monthPct < 34 ? .red : (monthPct < 67 ? .yellow : .green))
                        Text(String(format: "Week Success: %.0f%%", weekPct))
                            .font(.subheadline)
                            .foregroundColor(weekPct < 34 ? .red : (weekPct < 67 ? .yellow : .green))
                    }                    
                    HStack(spacing: 12) {
                        Button {
                            weekOffset -= 1
                            FeedbackManager.shared.tap()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        
                        Text(weekRangeTitle(weekOffset: weekOffset))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            weekOffset += 1
                            FeedbackManager.shared.tap()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    WeekdayHeaderRow(weekDates: viewModel.weekDates(for: weekOffset), dotSize: dotSize)
                        .padding(.horizontal)
                    
                    List {
                        ForEach(stableHabits) { habit in
                            BirdsEyeHabitRow(
                                habit: habit,
                                weekDates: viewModel.weekDates(for: weekOffset),
                                dotSize: dotSize,
                                isCompactWidth: isCompactWidth,
                                onOpenDetails: {
                                    navigationPath.append(habit.id)
                                }
                            ) {
                                statsSheet = StatsSheetContext(id: habit.id)
                            } onShowNotes: {
                                notesText = habit.notes ?? ""
                                notesSheet = NotesSheetContext(id: habit.id, title: habit.name, isArchived: habit.isArchived)
                            } onRetry: {
                                pendingRetryHabitId = habit.id
                                showingRetryConfirmation = true
                            } onArchive: {
                                pendingArchiveHabitId = habit.id
                                showingArchiveConfirmation = true
                            } onRename: {
                                renameHabitId = habit.id
                                renameText = habit.name
                                showingRenameAlert = true
                            } onDelete: {
                                pendingDeleteHabitId = habit.id
                                showingDeleteConfirmation = true
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
            .navigationDestination(for: UUID.self) { habitId in
                HabitDetailView(habitId: habitId)
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            stableHabits = viewModel.activeHabits
        }
        .onChange(of: viewModel.habits) { oldHabits, newHabits in
            updateStableHabits(with: newHabits)
        }
        .sheet(item: $statsSheet) { sheet in
            HabitStatsSheet(habitId: sheet.id)
                .environmentObject(viewModel)
        }
        .sheet(item: $notesSheet) { sheet in
            NotesEditorSheet(
                title: sheet.title,
                isReadOnly: sheet.isArchived,
                notesText: $notesText,
                onCancel: {
                    notesSheet = nil
                },
                onSave: {
                    viewModel.updateNotes(id: sheet.id, notes: notesText)
                }
            )
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
        .alert("Delete this habit?", isPresented: $showingDeleteConfirmation) {
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
    }
    
    private func updateStableHabits(with newHabits: [Habit]) {
        let activeNewHabits = newHabits.filter { !$0.isArchived }
        
        // 1. Keep existing habits that are still active, in their current order.
        // Also update their properties (like completion) so the row reflects changes.
        var updated = stableHabits.compactMap { stable in
            activeNewHabits.first(where: { $0.id == stable.id })
        }
        
        // 2. Append any truly new habits that weren't in our stable list before.
        let existingIds = Set(updated.map { $0.id })
        let trulyNew = activeNewHabits.filter { !existingIds.contains($0.id) }
        updated.append(contentsOf: trulyNew)
        
        stableHabits = updated
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
    let onOpenDetails: () -> Void
    let onShowStats: () -> Void
    let onShowNotes: () -> Void
    let onRetry: () -> Void
    let onArchive: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(habit.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenDetails()
            }
            .contextMenu {
                Button("Statistics", systemImage: "chart.bar") {
                    onShowStats()
                }
                Button("Notes", systemImage: "info.circle") {
                    onShowNotes()
                }
                Divider()
                Button("Retry", systemImage: "arrow.clockwise") {
                    onRetry()
                }
                Button("Archive", systemImage: "archivebox") {
                    onArchive()
                }
                Button("Rename", systemImage: "pencil") {
                    onRename()
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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
                    let now = Date()
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: now)
                    let month = calendar.component(.month, from: now)
                    
                    let lifetimePct = viewModel.successPercentage(for: habit)
                    let monthlyPct = viewModel.successPercentage(for: habit, year: year, month: month)
                    let streak = viewModel.currentStreak(for: habit)
                    let streakColor: Color = (streak == 0) ? .red : .green
                    
                    Text(habit.name)
                        .font(.title3)
                        .bold()
                        .padding(.bottom, 6)
                    Text("Current Streak: \(streak) day\(streak == 1 ? "" : "s")")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(streakColor)
                    
                    Text(String(format: "Success (This Month): %.0f%%", monthlyPct))
                        .font(.subheadline)
                        .foregroundColor(monthlyPct < 34 ? .red : (monthlyPct < 67 ? .yellow : .green))
                        
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

struct ReportsListView: View {
    @EnvironmentObject var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingInfoSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.reports) { report in
                    NavigationLink(destination: ReportDetailView(report: report)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(report.type.rawValue + " Report")
                                    .font(.headline)
                                Text(report.dateRange)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !report.isRead {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteReport)
            }
            .navigationTitle("Progress Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInfoSheet) {
                ReportsInfoSheet()
            }
        }
    }
}

struct ReportsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionView(title: "Statistics Modes", icon: "chart.bar.fill", color: .blue) {
                        Text("You can toggle between **All-Time** and **Monthly** statistics in the main view's options menu.")
                        Text("• **All-Time**: Shows success rate across the entire history of the habit.")
                        Text("• **Monthly**: Focuses on the current calendar month for a fresh start.")
                    }
                    
                    SectionView(title: "Smart Sorting", icon: "arrow.up.arrow.down", color: .orange) {
                        Text("In Monthly mode, the app uses **Hybrid Stability** sorting. If two habits are tied this month, it uses last month's performance as a tie-breaker so your list stays stable.")
                    }
                    
                    SectionView(title: "Automated Reports", icon: "doc.text.fill", color: .green) {
                        Text("Reports are generated automatically:")
                        Text("• **Weekly**: Every Monday morning for the previous week.")
                        Text("• **Monthly**: On the 1st of every month.")
                        Text("• **Catch-up**: If you haven't opened the app in a while, it will generate separate reports for every week or month you missed.")
                    }
                }
                .padding()
            }
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct ReportDetailView: View {
    let report: ProgressReport
    @EnvironmentObject var viewModel: HabitViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.dateRange)
                        .font(.title2)
                        .bold()
                    Text("\(report.type.rawValue) Summary")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .center, spacing: 12) {
                    Text("Overall Success")
                        .font(.headline)
                    Text(String(format: "%.0f%%", report.overallSuccess))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(report.overallSuccess < 34 ? .red : (report.overallSuccess < 67 ? .yellow : .green))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                if !report.topHabits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Strongest Habits", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(report.topHabits, id: \.self) { habit in
                            Text("• \(habit)")
                        }
                    }
                }
                
                if !report.focusHabits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Needs Focus", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        ForEach(report.focusHabits, id: \.self) { habit in
                            Text("• \(habit)")
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(report.type.rawValue + " Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.markReportAsRead(id: report.id)
        }
    }
}

struct MainHabitRow: View {
    @ObservedObject var viewModel: HabitViewModel
    let habit: Habit
    let onShowNotes: () -> Void
    
    var body: some View {
        let now = Date()
        let calendar = Calendar.current
        
        let hasMarks: Bool
        let pct: Double
        
        if viewModel.statMode == .allTime {
            hasMarks = !habit.completion.isEmpty
            pct = viewModel.successPercentage(for: habit)
        } else {
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            hasMarks = viewModel.hasMarks(for: habit, year: year, month: month)
            pct = viewModel.successPercentage(for: habit, year: year, month: month)
        }
        
        return HStack {
            Text(habit.name)
            if habit.isArchived {
                Text("Archived")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                    )
            }
            
            Button {
                onShowNotes()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            let streak = viewModel.currentStreak(for: habit)
            let streakColor: Color = (streak == 0) ? .red : .green
            let hasAnyMarks = !habit.completion.isEmpty
            let streakText = hasAnyMarks ? (streak > 99 ? "99+" : "\(streak)") : "–"
            let streakFill: Color = hasAnyMarks ? streakColor : .gray

            Text(streakText)
                .font(.caption)
                .frame(width: 25, height: 25)
                .background(
                    Circle()
                        .foregroundColor(streakFill)
                )
                .foregroundColor(.white)
            
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
    @State private var currentHabitId: UUID
    init(habitId: UUID) {
        _currentHabitId = State(initialValue: habitId)
    }
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
        viewModel.habits.first(where: { $0.id == currentHabitId })
    }
    
    private var isReadOnly: Bool {
        habit?.isArchived ?? false
    }
    
    private var navigationHabits: [Habit] {
        if habit?.isArchived == true {
            return viewModel.archivedHabits
        } else {
            return viewModel.activeHabits
        }
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
                if !isReadOnly {
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
                viewModel.resetHabit(id: currentHabitId)
                FeedbackManager.shared.tap()
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Archive this habit?", isPresented: $showingArchiveConfirmation) {
            Button("Archive") {
                viewModel.archiveHabit(id: currentHabitId)
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
                isReadOnly: isReadOnly,
                notesText: $notesText,
                onCancel: {
                    showingNotesSheet = false
                },
                onSave: {
                    viewModel.updateNotes(id: currentHabitId, notes: notesText)
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
        let canNavigate = navigationHabits.count > 1
        return HStack(alignment: .center, spacing: 0) {
            Button {
                navigateToPreviousHabit()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canNavigate)

            Spacer(minLength: 12)

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
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 12)

            Button {
                navigateToNextHabit()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canNavigate)
        }
        .padding(.top, headerTopPadding(isCompactWidth: isCompactWidth))
        .padding(.horizontal)
    }

    private func headerTopPadding(isCompactWidth: Bool) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize || isCompactWidth {
            return 25
        }
        return 75
    }

    private func navigateToPreviousHabit() {
        guard !navigationHabits.isEmpty,
              let idx = navigationHabits.firstIndex(where: { $0.id == currentHabitId }) else { return }
        let newIndex = (idx - 1 + navigationHabits.count) % navigationHabits.count
        currentHabitId = navigationHabits[newIndex].id
        FeedbackManager.shared.tap()
    }

    private func navigateToNextHabit() {
        guard !navigationHabits.isEmpty,
              let idx = navigationHabits.firstIndex(where: { $0.id == currentHabitId }) else { return }
        let newIndex = (idx + 1) % navigationHabits.count
        currentHabitId = navigationHabits[newIndex].id
        FeedbackManager.shared.tap()
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
                            guard !isReadOnly else { return }
                            switch completed {
                            case nil:
                                FeedbackManager.shared.success()
                                viewModel.markCompletion(habitId: habit.id, dateString: dateString, completed: true)
                            case true:
                                FeedbackManager.shared.failure()
                                viewModel.markCompletion(habitId: habit.id, dateString: dateString, completed: false)
                            case false:
                                FeedbackManager.shared.tap()
                                viewModel.removeCompletion(habitId: habit.id, dateString: dateString)
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
            let streakColor: Color = (streak == 0) ? .red : .green
            
            let now = Date()
            let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
            let year = calendar.component(.year, from: targetDate)
            let month = calendar.component(.month, from: targetDate)
            let monthlyPct = viewModel.successPercentage(for: habit, year: year, month: month)

            VStack(alignment: .center, spacing: 6) {
                Text("Current Streak: \(streak) day\(streak == 1 ? "" : "s")")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(streakColor)
                
                Text(String(format: "Success (Monthly): %.0f%%", monthlyPct))
                    .font(.subheadline)
                    .foregroundColor(monthlyPct < 34 ? .red : (monthlyPct < 67 ? .yellow : .green))

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
    let isReadOnly: Bool
    @Binding var notesText: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var isKeyboardVisible = false
    
    init(
        title: String,
        isReadOnly: Bool = false,
        notesText: Binding<String>,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.title = title
        self.isReadOnly = isReadOnly
        self._notesText = notesText
        self.onCancel = onCancel
        self.onSave = onSave
    }
    
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
                    .disabled(isReadOnly)
                    .onChange(of: notesText) { _, _ in
                        guard !isReadOnly else { return }
                        onSave()
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
                        hideKeyboard()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isKeyboardVisible)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
}

#Preview {
    ContentView()
}

