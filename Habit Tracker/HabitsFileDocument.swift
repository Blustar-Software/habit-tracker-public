//
//  HabitsFileDocument.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 1/29/26.
//  © Blustar Software. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct HabitsFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    static let empty = HabitsFileDocument(data: HabitsFileDocument.emptyJSONData)
    
    var data: Data
    
    init(data: Data = HabitsFileDocument.emptyJSONData) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? HabitsFileDocument.emptyJSONData
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
    
    private static var emptyJSONData: Data {
        Data("[]".utf8)
    }
}
