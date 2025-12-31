//
//  FeedbackManager.swift
//  Habit Tracker
//
//  Created by Blake McCowan on 11/25/25.
// © Blustar Software. All rights reserved.
//

import UIKit

class FeedbackManager {
    static let shared = FeedbackManager()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactLightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let impactMediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private init() {
        selectionGenerator.prepare()
        impactLightGenerator.prepare()
        impactMediumGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Haptic Feedback

    func triggerSelection() {
        selectionGenerator.selectionChanged()
    }

    func triggerSuccess() {
        notificationGenerator.notificationOccurred(.success)
    }

    func triggerWarning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func triggerError() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    func triggerLightImpact() {
        impactLightGenerator.impactOccurred()
    }
    
    func triggerMediumImpact() {
        impactMediumGenerator.impactOccurred()
    }

    // MARK: - Sound Feedback

    // A neutral, crisp tap sound. Good for selections or confirmations.
    func playNeutralSound() {
    }
    
    // A sound to indicate success.
    func playSuccessSound() {
    }
    
    // A sound for warnings or non-critical errors.
    func playWarningSound() {
    }
    
    // A sound for failure.
    func playFailureSound() {
    }

    // A sound for significant actions like deletion.
    func playDeleteSound() {
        // No sound for deletion, haptic feedback will suffice.
    }

    // MARK: - Combined Feedback Events

    func success() {
        triggerSuccess()
        playSuccessSound()
    }
    
    func warning() {
        triggerWarning()
        playWarningSound()
    }
    
    func failure() {
        triggerWarning()
        playFailureSound()
    }
    
    func error() {
        triggerError()
        playDeleteSound() // Using a more impactful sound for general errors/deletions
    }
    
    func tap() {
        triggerLightImpact()
        playNeutralSound()
    }
    
    func selection() {
        triggerSelection()
        // Often, selection sounds can be too noisy, so we might only use haptics.
        // If sound is desired, playTapSound() could be called here.
    }
}
