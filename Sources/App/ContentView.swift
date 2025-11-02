// Sources/App/ContentView.swift
import SwiftUI
import Combine
import AVFoundation

/// Main UI for SailTact. Shows SOG, headings, VMG, TWD/TWA input, map and controls.
struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var hapticsManager: HapticsManager
    @StateObject private var sogHistory = SOGHistory()

    // User settings
    @State private var useTWAInput = false
    @State private var twdInputStr = "0" // when using TWD input
    @State private var twaInputStr = "0" // when using TWA input
    @State private var threshold_mps: Double = 0.1
    @State private var evalInterval: TimeInterval = 30
    @State private var alertsEnabled: Bool = false
    @State private var showSettings = false
    @State private var twaPositiveStarboard = true
    @State private var showRecommendation: String? = nil
    @State private var voiceAnnounce = false
    // The angle by which heading will change when tacking/jibing.
    // Default 90°: switching tack rotates heading by ±90° relative to current heading.
    // Positive value means magnitude of the change; sign/direction depends on current tack.
    @State private var preferredTurnAngle_deg: Double = 90.0

    @State private var timerCancellable: AnyCancellable?
    @State private var lastDecisionTime: Date? = nil

    // AVSpeech synthesizer for optional voice announce
    private let synthesizer = AVSpeechSynthesizer()

    // Convert input strings to degrees sensibly
    private var twdDeg: Double? {
        if useTWAInput {
            // need current boat heading
            guard let heading = locationManager.status.heading_deg ?? locationManager.status.cog_deg else { return nil }
            guard let twa = Double(twaInputStr) else { return nil }
            // TWA: relative to bow. User can choose sign convention in Settings.
            // If twaPositiveStarboard == true, positive TWA means wind to starboard (right), so TWD = heading + TWA.
            // If false, positive TWA means wind to port (left), so TWD = heading - TWA.
            let raw = twaPositiveStarboard ? (heading + twa) : (heading - twa)
            let twd = VMGCalculator.normalizeDegrees360(raw)
            return twd
        } else {
            guard let v = Double(twdInputStr) else { return nil }
            return VMGCalculator.normalizeDegrees360(v)
        }
    }

    // Convenience for display
    private var sog_mps: Double { locationManager.status.sog_mps ?? 0.0 }
    private var sog_knots: Double { sog_mps / 0.514444 }
    private var headingDeg: Double? { locationManager.status.heading_deg ?? locationManager.status.cog_deg }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Top info area
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("SOG: \(String(format: "%.2f", sog_mps)) m/s")
                            .font(.title2)
                        Text("(\(String(format: "%.2f", sog_knots)) kn)")
                            .font(.subheadline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Heading: \(headingDeg.map { String(format: "%.0f°", $0) } ?? "—")")
                        Text("COG: \(locationManager.status.cog_deg.map { String(format: "%.0f°", $0) } ?? "—")")
                    }
                }
                .padding([.leading, .trailing])

                // VMG display and formula
                VStack(alignment: .leading, spacing:4) {
                    if let heading = headingDeg, let twd = twdDeg {
                        let v = VMGCalculator.vmg(sog_mps: sog_mps, headingDeg: heading, twdDeg: twd)
                        Text("VMG = SOG * cos(Δ)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(String(format: "VMG: %.2f m/s", v))
                            .font(.headline)
                            .bold()
                    } else {
                        Text("VMG: — (need heading + TWD/TWA)")
                            .font(.headline)
                    }
                }
                .padding([.leading, .trailing])

                // Input area
                HStack {
                    Toggle(isOn: $useTWAInput) { Text(useTWAInput ? "Input: TWA" : "Input: TWD") }
                    .accessibilityLabel("Toggle input mode TWA or TWD")
                    Spacer()
                    if useTWAInput {
                        TextField("TWA°", text: $twaInputStr)
                            .keyboardType(.numbersAndPunctuation)
                            .frame(width:80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .accessibilityLabel("True wind angle input")
                    } else {
                        TextField("TWD°", text: $twdInputStr)
                            .keyboardType(.numbersAndPunctuation)
                            .frame(width:100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .accessibilityLabel("True wind direction input")
                    }
                }
                .padding([.leading, .trailing])

                // Map
                MapView()
                    .environmentObject(locationManager)
                    .frame(height: 260)
                    .cornerRadius(10)
                    .padding([.leading, .trailing])

                // Controls
                HStack(spacing: 12) {
                    Button(action: {
                        locationManager.setStartWaypoint()
                        // haptic + brief visual confirmation
                        hapticsManager.playTwoPulseAlert()
                        showTemporaryMessage("Start waypoint saved")
                    }) {
                        Text("Set Start Waypoint")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Set start waypoint")

                    VStack {
                        Toggle(isOn: $alertsEnabled) { Text("VMG Alerts") }
                            .accessibilityLabel("Start or stop VMG alerts")
                    }
                    .frame(width:140)
                }
                .padding([.leading, .trailing])

                if let dist = locationManager.distanceToWaypoint_m, let bearing = locationManager.bearingToWaypoint_deg {
                    HStack {
                        Text(String(format: "To start: %.0f m — %.0f°", dist, bearing))
                        Spacer()
                    }
                    .padding([.leading, .trailing])
                }

                Spacer()
            }
            .navigationTitle("SailTact")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) { Image(systemName: "gear") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    threshold: $threshold_mps,
                    interval: $evalInterval,
                    voiceAnnounce: $voiceAnnounce,
                    preferredTurnAngle: $preferredTurnAngle_deg,
                    binWidthDeg: Binding(get: { self.sogHistory.binWidthDeg }, set: { self.sogHistory.binWidthDeg = $0 }),
                    maxSamplesPerBin: Binding(get: { self.sogHistory.maxSamplesPerBin }, set: { self.sogHistory.maxSamplesPerBin = $0 }),
                    twaPositiveStarboard: $twaPositiveStarboard
                )
            }
            .onChange(of: alertsEnabled) { enabled in
                if enabled { startAlertTimer() } else { stopAlertTimer() }
            }
            .onDisappear { stopAlertTimer() }
            // Record SOG samples for adaptive per-tack averaging when status updates
            .onReceive(locationManager.$status) { status in
                // Need valid heading (device heading or COG), SOG and TWD
                guard let heading = status.heading_deg ?? status.cog_deg,
                      let sog = status.sog_mps,
                      let twd = self.twdDeg else {
                    return
                }
                // TWA magnitude (degrees)
                let signed = VMGCalculator.smallestSignedAngleDifference(from: heading, to: twd)
                let twaMag = abs(signed)
                let tack: TackSide = signed > 0 ? .port : .starboard
                sogHistory.recordSample(twa: twaMag, tack: tack, sog_mps: sog)
            }
            .overlay(
                Group {
                    if let msg = showRecommendation {
                        RecommendationView(message: msg)
                            .transition(.move(edge: .top))
                    }
                }, alignment: .top
            )
        }
    }

    // We record SOG samples when location/heading updates arrive and we have a TWD.
    // Recording happens on the main thread via SOGHistory's thread-safe API.

    // MARK: - Timer control
    private func startAlertTimer() {
        stopAlertTimer()
        // Use Combine Timer publisher
        timerCancellable = Timer.publish(every: evalInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                evaluateForManeuver()
            }
    }

    private func stopAlertTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Evaluation logic (every interval)
    private func evaluateForManeuver() {
        guard let heading = locationManager.status.heading_deg ?? locationManager.status.cog_deg else { return }
        guard let twd = twdDeg else { return }
        let currentVMG = VMGCalculator.vmg(sog_mps: sog_mps, headingDeg: heading, twdDeg: twd)

    // Determine alt heading using the configured turn angle when switching tacks.
    // The user configures the magnitude of the heading change when tacking (default 90°).
    // We compute the candidate altHeading by rotating the CURRENT HEADING by ±preferredTurnAngle
    // depending on the current tack. This models how the helmsman actually changes course.
    // If currently on port tack, switching to starboard reduces heading by turnAngle (example: 180 -> 90).
    // If currently on starboard tack, switching to port increases heading by turnAngle (example: 300 -> 30).
    let signed = VMGCalculator.smallestSignedAngleDifference(from: heading, to: twd)
    let currentTack: TackSide = signed > 0 ? .port : .starboard
    let turnSign: Double = (currentTack == .port) ? -1.0 : 1.0
    let altHeading = VMGCalculator.normalizeDegrees360(heading + turnSign * preferredTurnAngle_deg)

        // Compute alt TWA magnitude (degrees)
        let altTwa = abs(VMGCalculator.smallestSignedAngleDifference(from: altHeading, to: twd))

    // Lookup predicted SOG for altTwa on the opposite tack from history
    let predictedSOG = sogHistory.averageSpeed(forTWADegrees: altTwa, tack: oppositeTack) ?? sog_mps

        // Compute predicted alt VMG using the predicted SOG
        let altVMG = VMGCalculator.vmg(sog_mps: predictedSOG, headingDeg: altHeading, twdDeg: twd)

        // If altVMG > currentVMG + threshold -> recommend
        if altVMG > currentVMG + threshold_mps {
            // Determine whether this is tack (upwind) or jibe (downwind)
            let maneuver = currentVMG >= 0 ? "Tack" : "Jibe"
            // Choose arrow direction based on signed angle from heading to altHeading
            let turnDeg = VMGCalculator.smallestSignedAngleDifference(from: heading, to: altHeading)
            let arrow = turnDeg > 0 ? "→" : "←"
            let msg = "\(maneuver) now \(arrow)"
            showRecommendationWithHapticAndVoice(msg: msg)
        } else {
            // No significant improvement; no alert
        }
    }

    private func showRecommendationWithHapticAndVoice(msg: String) {
        showTemporaryMessage(msg)
        hapticsManager.playTwoPulseAlert()
        if voiceAnnounce {
            let utter = AVSpeechUtterance(string: msg)
            utter.voice = AVSpeechSynthesisVoice(language: "en-US")
            utter.rate = 0.45
            synthesizer.speak(utter)
        }
    }

    private func showTemporaryMessage(_ text: String, duration: TimeInterval = 3) {
        withAnimation { showRecommendation = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation { showRecommendation = nil }
        }
    }
}

// MARK: - Settings view
struct SettingsView: View {
    @Binding var threshold: Double
    @Binding var interval: TimeInterval
    @Binding var voiceAnnounce: Bool
    @Binding var preferredTurnAngle: Double
    @Binding var binWidthDeg: Double
    @Binding var maxSamplesPerBin: Int
    @Binding var twaPositiveStarboard: Bool

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("VMG Alerts")) {
                    HStack {
                        Text("Threshold (m/s)")
                        Spacer()
                        Text(String(format: "%.2f", threshold))
                    }
                    Slider(value: $threshold, in: 0...2, step: 0.01)

                    HStack {
                        Text("Interval (s)")
                        Spacer()
                        Text(String(format: "%.0f", interval))
                    }
                    Slider(value: Binding(get: { interval }, set: { interval = $0 }), in: 10...120, step: 1)

                    Toggle(isOn: $voiceAnnounce) { Text("Voice announce") }
                }

                Section(header: Text("Tack preferences")) {
                    HStack {
                        Text("Preferred turn angle")
                        Spacer()
                        Text(String(format: "%.0f°", preferredTurnAngle))
                    }
                    // Turn angle is how much the heading changes when switching tack (default 90°)
                    Slider(value: $preferredTurnAngle, in: 10...180, step: 1)
                }
                Section(header: Text("Learning (SOG history)")) {
                    HStack {
                        Text("TWA bin width")
                        Spacer()
                        Text(String(format: "%.0f°", binWidthDeg))
                    }
                    Slider(value: $binWidthDeg, in: 1...20, step: 1)

                    HStack {
                        Text("Max samples/bin")
                        Spacer()
                        Text("\(maxSamplesPerBin)")
                    }
                    Stepper(value: $maxSamplesPerBin, in: 5...500, step: 5) {
                        EmptyView()
                    }
                }
                Section(header: Text("TWA sign convention")) {
                    Toggle(isOn: $twaPositiveStarboard) {
                        Text("TWA positive to starboard (right)")
                    }
                    Button(action: {
                        // Quick calibration helper: flip to the opposite convention
                        twaPositiveStarboard.toggle()
                    }) {
                        Text("Flip convention")
                    }
                    .foregroundColor(.accentColor)
                    Text("If your instrument/TWA source uses the opposite sign, flip this.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.dismiss(animated: true) }
                }
            }
        }
    }
}

// MARK: - Recommendation banner
struct RecommendationView: View {
    let message: String
    var body: some View {
        HStack {
            Spacer()
            Text(message)
                .bold()
                .padding()
                .background(Color.yellow)
                .cornerRadius(8)
            Spacer()
        }
        .padding()
    }
}

#if DEBUG
import SwiftUI
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LocationManager())
            .environmentObject(HapticsManager())
    }
}
#endif
