//
//  LaunchView.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 11/25/25.
// © Blustar Software. All rights reserved.
//

import SwiftUI

struct LaunchView: View {
    @State private var isActive = false
    @ObservedObject var fileManager = HabitFileManager.shared
    
    var body: some View {
        if isActive {
            if fileManager.needsFileSelection {
                FileSelectionView()
            } else {
                ContentView()
            }
        } else {
            ZStack {
                // Set your desired background color or image
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Replace "LaunchLogo" with the actual name of your logo asset
                    Image("LaunchLogo") 
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200) // Adjust size as needed
                    // Add any other launch screen elements like text here
                    // Text("Habit Tracker")
                    //    .font(.largeTitle)
                    //    .foregroundColor(.black)
                }
            }
            .onAppear {
                // Simulate a delay for the launch screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 2 seconds delay
                    self.isActive = true
                }
            }
        }
    }
}

struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView()
    }
}
