//
//  FileSelectionView.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 12/10/25.
//  © Blustar Software. All rights reserved.
//

import SwiftUI

struct FileSelectionView: View {
    @ObservedObject var fileManager = HabitFileManager.shared
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                
                Text("Habit Tracker")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                
                Text("Choose how to manage your habit data")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    Button(action: {
                        createNewFile()
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Create New File")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                    
                    Button(action: {
                        openExistingFile()
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Open Existing File")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    private func createNewFile() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        isProcessing = true
        fileManager.presentCreateFilePicker(from: viewController) { success in
            isProcessing = false
        }
    }
    
    private func openExistingFile() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        isProcessing = true
        fileManager.presentOpenFilePicker(from: viewController) { success in
            isProcessing = false
        }
    }
}

#Preview {
    FileSelectionView()
}
