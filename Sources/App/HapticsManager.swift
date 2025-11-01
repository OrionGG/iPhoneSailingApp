// Sources/App/HapticsManager.swift
import Foundation
import UIKit
import CoreHaptics

/// HapticsManager manages a two-pulse haptic alert using CoreHaptics when available,
/// and falls back to UIFeedbackGenerator on older devices / when CoreHaptics isn't available.
final public class HapticsManager: ObservableObject {
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    public init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            supportsHaptics = true
            do {
                engine = try CHHapticEngine()
                try engine?.start()
            } catch {
                supportsHaptics = false
                engine = nil
                print("Failed to start CoreHaptics: \(error)")
            }
        } else {
            supportsHaptics = false
        }
    }

    /// Play two short pulses separated by approximately 200ms.
    public func playTwoPulseAlert() {
        if supportsHaptics, let engine = engine {
            // Build a simple pattern: two transient events at t=0 and t=0.2s
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let first = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            let second = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0.2)
            do {
                let pattern = try CHHapticPattern(events: [first, second], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                print("CoreHaptics playback failed: \(error)")
                supportsHaptics = false
                fallbackTwoPulse()
            }
        } else {
            fallbackTwoPulse()
        }
    }

    /// Fallback: two UIFeedbackGenerator notifications spaced by 0.2s.
    private func fallbackTwoPulse() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let g2 = UINotificationFeedbackGenerator()
            g2.prepare()
            g2.notificationOccurred(.success)
        }
    }
}
