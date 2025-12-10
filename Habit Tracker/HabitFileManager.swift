//
//  HabitFileManager.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 12/10/25.
//  © Blustar Software. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

class HabitFileManager: NSObject, ObservableObject {
    static let shared = HabitFileManager()
    
    @Published var fileURL: URL?
    @Published var needsFileSelection = false
    
    private let bookmarkKey = "HabitFileBookmark"
    private let originalPathKey = "HabitFileOriginalPath"
    
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
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
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
                clearBookmarkData()
                shouldShowAlert = true
                needsFileSelection = true
                showFileAccessAlertIfNeeded(shouldShow: shouldShowAlert)
                return
            }
            
            self.fileURL = url
            needsFileSelection = false
        } catch {
            print("Error resolving bookmark: \(error)")
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
            self.fileURL = url
            needsFileSelection = false
        } catch {
            print("Error saving bookmark: \(error)")
        }
    }
    
    func clearBookmark() {
        if let url = fileURL {
            url.stopAccessingSecurityScopedResource()
        }
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
    }
    
    // MARK: - File Operations
    
    func saveHabits(_ habits: [Habit]) {
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
            let data = try encoder.encode(habits)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Error saving habits: \(error)")
            handleFileAccessError()
        }
    }
    
    func loadHabits() -> [Habit] {
        guard let url = fileURL else {
            handleFileAccessError()
            return []
        }
        
        // Check if file still exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File no longer exists at path")
            handleFileAccessError()
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let habits = try decoder.decode([Habit].self, from: data)
            return habits
        } catch {
            print("Error loading habits: \(error)")
            handleFileAccessError()
            // If file is corrupted or can't be read, start fresh
            return []
        }
    }
    
    private func handleFileAccessError() {
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
