//
//  HabitFileManager.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 12/10/25.
//  © Blustar Software. All rights reserved.
//

import Foundation
import Darwin
import UIKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

class HabitFileManager: NSObject, ObservableObject {
    static let shared = HabitFileManager()
    static let fileDidChangeNotification = Notification.Name("HabitFileDidChangeNotification")
    
    @Published var fileURL: URL?
    @Published var needsFileSelection = false
    
    private let bookmarkKey = "HabitFileBookmark"
    private let originalPathKey = "HabitFileOriginalPath"
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var monitoredFileDescriptor: Int32 = -1
    private var lastKnownModificationDate: Date?
    
    private override init() {
        super.init()
        checkForExistingBookmark()
    }
    
    // MARK: - Bookmark Management
    
    func checkForExistingBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey),
              let originalPath = UserDefaults.standard.string(forKey: originalPathKey) else {
            needsFileSelection = true
            return
        }
        
        var shouldShowAlert = false
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Bookmark is stale, need to recreate it
                if attemptRepairIfPossible(originalPath: originalPath) {
                    return
                }
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                if attemptRepairIfPossible(originalPath: originalPath) {
                    return
                }
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            // CRITICAL: Check if file is at the EXACT same path (no tracking)
            if url.path != originalPath {
                print("File has moved from original location")
                url.stopAccessingSecurityScopedResource()
                if attemptRepairIfPossible(originalPath: originalPath) {
                    return
                }
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            // Check if file is in trash/recently deleted
            let pathString = url.path.lowercased()
            if pathString.contains(".trash") || pathString.contains("recently deleted") {
                print("File is in trash")
                url.stopAccessingSecurityScopedResource()
                if attemptRepairIfPossible(originalPath: originalPath) {
                    return
                }
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            // Try to actually read the file to verify it's truly accessible
            guard FileManager.default.fileExists(atPath: url.path),
                  FileManager.default.isReadableFile(atPath: url.path),
                  (try? Data(contentsOf: url)) != nil else {
                print("File exists but cannot be read")
                url.stopAccessingSecurityScopedResource()
                if attemptRepairIfPossible(originalPath: originalPath) {
                    return
                }
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            self.fileURL = url
            needsFileSelection = false
            startMonitoringFile(at: url)
            refreshLastKnownModificationDate(for: url)
        } catch {
            print("Error resolving bookmark: \(error)")
            if attemptRepairIfPossible(originalPath: originalPath) {
                return
            }
            clearBookmarkData()
            shouldShowAlert = true
            needsFileSelection = true
            showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
        }
    }
    
    private func showFileAccessAlertIfNeeded(shouldShow: Bool) {
        guard shouldShow else { return }
        // Delay slightly to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showFileAccessAlert()
        }
    }
    
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            UserDefaults.standard.set(url.path, forKey: originalPathKey) // Store original path
            DispatchQueue.main.async {
                self.fileURL = url
                self.needsFileSelection = false
                self.startMonitoringFile(at: url)
                self.refreshLastKnownModificationDate(for: url)
            }
        } catch {
            print("Error saving bookmark: \(error)")
        }
    }
    
    func clearBookmark() {
        if let url = fileURL {
            url.stopAccessingSecurityScopedResource()
        }
        stopMonitoringFile()
        lastKnownModificationDate = nil
        clearBookmarkData()
        fileURL = nil
        needsFileSelection = true
    }
    
    private func clearBookmarkData() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: originalPathKey)
    }
    
    // Call this when app becomes active to verify file is still accessible
    func verifyFileAccess() {
        guard let url = fileURL,
              let originalPath = UserDefaults.standard.string(forKey: originalPathKey) else { 
            return 
        }
        
        // Check if file has moved from original location
        if url.path != originalPath {
            print("File verification failed - file has moved")
            handleFileAccessError()
            return
        }
        
        // Check if file is in trash
        let pathString = url.path.lowercased()
        if pathString.contains(".trash") || pathString.contains("recently deleted") {
            print("File verification failed - file is in trash")
            handleFileAccessError()
            return
        }
        
        // Try to actually read the file
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.isReadableFile(atPath: url.path),
              (try? Data(contentsOf: url)) != nil else {
            print("File verification failed - file no longer accessible")
            handleFileAccessError()
            return
        }
        
        notifyFileChangedIfNeeded(for: url)
    }
    
    // MARK: - File Operations
    
    func saveHabitData(_ data: HabitData) {
        guard let url = fileURL else {
            handleFileAccessError()
            return
        }
        
        // Check if file still exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File no longer exists at path")
            handleFileAccessError()
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(data)
            try data.write(to: url, options: .atomic)
            refreshLastKnownModificationDate(for: url)
        } catch {
            print("Error saving habits: \(error)")
            handleFileAccessError()
        }
    }
    
    func loadHabitData() -> HabitData {
        guard let url = fileURL else {
            handleFileAccessError()
            return HabitData()
        }
        
        // Check if file still exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File no longer exists at path")
            handleFileAccessError()
            return HabitData()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // Try decoding as HabitData first
            if let habitData = try? decoder.decode(HabitData.self, from: data) {
                refreshLastKnownModificationDate(for: url)
                return habitData
            }
            
            // Fallback for older files which only had [Habit]
            if let habits = try? decoder.decode([Habit].self, from: data) {
                refreshLastKnownModificationDate(for: url)
                return HabitData(habits: habits, reports: [])
            }
            
            return HabitData()
        } catch {
            print("Error loading habits: \(error)")
            handleFileAccessError()
            return HabitData()
        }
    }

    // Deprecated helpers for compatibility with existing code during transition
    func saveHabits(_ habits: [Habit]) {
        let currentData = loadHabitData()
        saveHabitData(HabitData(habits: habits, reports: currentData.reports))
    }
    
    func loadHabits() -> [Habit] {
        return loadHabitData().habits
    }
    
    private func handleFileAccessError() {
        if attemptRepairIfPossible() {
            return
        }
        
        // Clear the invalid bookmark and trigger file selection
        DispatchQueue.main.async {
            self.clearBookmark()
            self.showFileAccessAlert()
        }
    }
    
    private func showFileAccessAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "File Not Found",
            message: "The habits file could not be found or accessed. Please select or create a new file.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        viewController.present(alert, animated: true)
    }
    
    // MARK: - File Monitoring and Repair
    
    private func startMonitoringFile(at url: URL) {
        stopMonitoringFile()
        
        monitoredFileDescriptor = open(url.path, O_EVTONLY)
        guard monitoredFileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: monitoredFileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        source.setCancelHandler { [weak self] in
            guard let self = self, self.monitoredFileDescriptor >= 0 else { return }
            close(self.monitoredFileDescriptor)
            self.monitoredFileDescriptor = -1
        }
        
        fileMonitorSource = source
        source.resume()
    }
    
    private func stopMonitoringFile() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }
    
    private func handleFileSystemEvent() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.handleFileChangeIfPossible()
        }
    }
    
    private func handleFileChangeIfPossible() {
        guard let url = fileURL else { return }
        
        if FileManager.default.fileExists(atPath: url.path),
           FileManager.default.isReadableFile(atPath: url.path) {
            notifyFileChangedIfNeeded(for: url)
            return
        }
        
        if !attemptRepairIfPossible() {
            handleFileAccessError()
        }
    }
    
    private func notifyFileChangedIfNeeded(for url: URL) {
        guard hasModificationDateChanged(for: url) else { return }
        postFileChangedNotification()
        refreshLastKnownModificationDate(for: url)
    }
    
    private func postFileChangedNotification() {
        NotificationCenter.default.post(name: Self.fileDidChangeNotification, object: nil)
    }
    
    private func refreshLastKnownModificationDate(for url: URL) {
        lastKnownModificationDate = currentModificationDate(for: url)
    }
    
    private func hasModificationDateChanged(for url: URL) -> Bool {
        guard let current = currentModificationDate(for: url) else { return false }
        return lastKnownModificationDate != current
    }
    
    private func currentModificationDate(for url: URL) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date
    }
    
    private func attemptRepairIfPossible(originalPath: String? = nil) -> Bool {
        let storedPath = originalPath ?? UserDefaults.standard.string(forKey: originalPathKey)
        guard let path = storedPath else { return false }
        
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }
        
        _ = url.startAccessingSecurityScopedResource()
        saveBookmark(for: url)
        postFileChangedNotification()
        return true
    }
    
    // MARK: - Document Picker
    
    func presentCreateFilePicker(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let picker = UIDocumentPickerViewController(forExporting: [createTemporaryFile()], asCopy: false)
        picker.delegate = self
        picker.shouldShowFileExtensions = true
        
        // Store completion handler
        self.documentPickerCompletion = completion
        
        viewController.present(picker, animated: true)
    }
    
    func presentOpenFilePicker(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = self
        picker.shouldShowFileExtensions = true
        picker.allowsMultipleSelection = false
        
        // Store completion handler
        self.documentPickerCompletion = completion
        
        viewController.present(picker, animated: true)
    }
    
    private func createTemporaryFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("habits.json")
        
        // Create empty array as initial data
        let emptyHabits: [Habit] = []
        if let data = try? JSONEncoder().encode(emptyHabits) {
            try? data.write(to: tempFile)
        }
        
        return tempFile
    }
    
    private var documentPickerCompletion: ((Bool) -> Void)?
}

// MARK: - UIDocumentPickerDelegate

extension HabitFileManager: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            documentPickerCompletion?(false)
            return
        }
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            documentPickerCompletion?(false)
            return
        }
        
        saveBookmark(for: url)
        documentPickerCompletion?(true)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        documentPickerCompletion?(false)
    }
}
