// Sources/App/MainApp.swift
import SwiftUI

@main
struct SailTactApp: App {
    // Shared view models/managers
    @StateObject private var locationManager = LocationManager()
    @StateObject private var hapticsManager = HapticsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(hapticsManager)
        }
    }
}
