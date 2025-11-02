# Example Run Log (simulated) — turn-angle + SOG history

This log shows a 120-second simulated run, with periodic location updates, recorded SOG samples grouped into 5° TWA bins, and the 30s decision points where the system uses the configured turn angle (default 90°) to build the candidate heading on the opposite tack and evaluate predicted altVMG using learned per-tack SOG.

Assumptions:
- Initial heading: 30°
- True Wind Direction (TWD): 0° (wind from North)
- Preferred turn angle: 90° (default setting in the app)
- Threshold: 0.1 m/s
- Eval interval: 30s
- SOGHistory bin width: 5° (bins are 0-5°, 5-10°, ...), maxSamplesPerBin = 50

Samples recorded (time, heading, SOG) — these populate SOGHistory by TWA-bin and tack:
- t= 5s:  heading=30°, SOG=3.00 m/s -> TWA = |30 - 0| = 30° -> bin 30..35° -> tack = starboard
- t=10s: heading=32°, SOG=3.05 m/s -> TWA ≈ 32° -> bin 30..35° -> tack = starboard
- t=15s: heading=31°, SOG=3.02 m/s -> TWA ≈ 31° -> bin 30..35° -> tack = starboard
- t=20s: heading=60°, SOG=2.90 m/s -> TWA = 60° -> bin 60..65° -> tack = starboard
- t=25s: heading=58°, SOG=2.95 m/s -> TWA ≈ 58° -> bin 55..60° -> tack = starboard
- t=35s: heading=300°, SOG=3.20 m/s -> TWA = |300 - 0| = 60° -> bin 60..65° -> tack = port
- t=45s: heading=305°, SOG=3.25 m/s -> TWA ≈ 55° -> bin 55..60° -> tack = port
- t=75s: heading=310°, SOG=3.30 m/s -> TWA ≈ 50° -> bin 50..55° -> tack = port

Recorded SOGHistory (example aggregated averages after these samples):
- Bin 30..35°, tack=starboard: samples = [3.00, 3.05, 3.02] -> avg ≈ 3.023 m/s
- Bin 55..60°, tack=starboard: samples = [2.95] -> avg ≈ 2.95 m/s
- Bin 60..65°, tack=starboard: samples = [2.90] -> avg ≈ 2.90 m/s
- Bin 60..65°, tack=port: samples = [3.20] -> avg ≈ 3.20 m/s
- Bin 55..60°, tack=port: samples = [3.25] -> avg ≈ 3.25 m/s
- Bin 50..55°, tack=port: samples = [3.30] -> avg ≈ 3.30 m/s

Now evaluate decisions every 30s using the configured turn angle (90°).

Time 30s decision (uses samples recorded up to t=25s):
- Current state at t=30s: heading ≈ 31°, SOG ≈ 3.02 m/s
- currentVMG = 3.02 * cos(smallestSignedAngleDifference(31, 0)) = 3.02 * cos(-31°) ≈ 2.59 m/s
- Current tack: starboard (signed = -31°)
- Opposite tack: port
- Compute altHeading using turn-angle relative to current heading:
  - current heading 31° on starboard -> switching to port rotates heading by +90° -> altHeading = normalizeDegrees360(31 + 90) = 121°
  - altTWA = abs(smallestSignedAngleDifference(121°, 0°)) = 121° -> bin 120..125°
- predictedSOG = SOGHistory.averageSpeed(forTWADegrees: 121°, tack: port)
  -> In our recorded samples we don't have bin 120..125° for port, so predictedSOG = nil -> fallback to current SOG = 3.02 m/s
- altVMG = predictedSOG * cos(angle between altHeading and TWD) = 3.02 * cos(121°) ≈ 3.02 * (-0.52) ≈ -1.57 m/s
- Compare: altVMG (-1.57) vs currentVMG (2.59) -> altVMG is much worse -> No recommendation

Time 60s decision (after samples at t=35s and t=45s):
- Example A: current state at t=60s: heading = 300°, SOG = 3.20 m/s, current tack = starboard
  - currentVMG = 3.20 * cos(smallestSignedAngleDifference(300, 0)) = 3.20 * cos(-60°) = 1.60 m/s
  - Opposite tack: port
  - Compute altHeading by rotating current heading by +90° (starboard -> port):
    altHeading = normalizeDegrees360(300 + 90) = 30° (port)
  - altTWA = abs(smallestSignedAngleDifference(30°, 0°)) = 30° -> bin 30..35°
  - predictedSOG = SOGHistory.averageSpeed(forTWADegrees: 30°, tack: port)
    -> from recorded samples above we have bin 30..35° for starboard (avg ≈ 3.023) but not for port yet; assume fallback predictedSOG = current SOG = 3.20 m/s
  - altVMG = predictedSOG * cos(30°) = 3.20 * 0.866 = 2.77 m/s
  - Compare: altVMG (2.77) vs currentVMG (1.60) -> altVMG > currentVMG + threshold -> Recommend: "Tack now →"

- Example B: current heading = 40°, SOG = 3.05 m/s, current tack = port
  - currentVMG = 3.05 * cos(smallestSignedAngleDifference(40, 0)) = 3.05 * cos(40°) ≈ 2.34 m/s
  - Opposite tack: starboard
  - Compute altHeading by rotating current heading by -90° (port -> starboard):
    altHeading = normalizeDegrees360(40 - 90) = 310° (starboard)
  - altTWA = abs(smallestSignedAngleDifference(310°, 0°)) = 50° -> bin 50..55°
  - predictedSOG = SOGHistory.averageSpeed(forTWADegrees: 50°, tack: starboard)
    -> from recorded samples above, bin 50..55° for port avg ≈ 3.30; starboard has no samples for 50..55° -> fallback to current SOG = 3.05 m/s
  - altVMG = predictedSOG * cos(50°) = 3.05 * cos(50°) ≈ 3.05 * 0.643 = 1.96 m/s
  - Compare: altVMG (1.96) vs currentVMG (2.34) -> altVMG is worse -> No recommendation

Summary: Using the configured turn angle (±90° by default) to compute the candidate altHeading makes the evaluation reflect the realistic heading change the helmsman will execute when switching tack. The SOGHistory provides predictedSOG for that altTWA/bin on the opposite tack; when the historical predictedSOG yields a higher altVMG beyond the threshold, the app recommends the maneuver. When no history exists for the desired bin/tack, the algorithm conservatively falls back to the current SOG.