# Example Run Log (simulated)

This log shows a 90-second simulated run with status updates every ~10s and the 30s decision points.

Assumptions: starting boat heading ~30°, SOG ~3.0 m/s, TWD = 0° (wind from North). Threshold = 0.1 m/s, interval = 30s.

Time 0s: heading=30°, SOG=3.00 m/s, TWD=0°
- Δ = smallestSignedAngleDifference(30, 0) = -30°
- VMG = 3.00 * cos(-30°) = 3.00 * 0.8660 = 2.598 m/s (positive -> upwind progress)

Time 30s decision:
- currentVMG = 2.598
- altHeading = normalize(2*TWD - heading) = normalize(0 - 30) = 330°
- altVMG = 3.00 * cos(angle between 330° and 0° -> 30°) = 2.598
- altVMG - currentVMG = 0.000 -> no recommendation

Time 40s: boat adjusts to heading=60° (drift)
- SOG=2.9 m/s, heading=60°, Δ = smallestSignedAngleDifference(60,0) = -60°
- VMG = 2.9 * cos(60°) = 2.9 * 0.5 = 1.45 m/s

Time 60s decision:
- currentVMG = 1.45
- altHeading = normalize(0 - 60) = 300°
- altVMG = 2.9 * cos(60°) = 1.45
- altVMG - currentVMG = 0.0 -> no recommendation

Time 70s: boat holds heading=300° (attempt starboard tack), SOG=3.2
- heading=300°, Δ = smallestSignedAngleDifference(300,0) = 300>180 -> -60° => VMG = 3.2 * cos(-60°) = 1.6 m/s

Time 90s decision:
- currentVMG = 1.6
- altHeading = normalize(0 - 300) = 60°
- altVMG = 3.2 * cos(60°) = 1.6 m/s
- No recommendation (symmetric)

Notes: with identical SOG and symmetric headings, altVMG ~= currentVMG. Recommendations occur when mirrored tack produces higher projected VMG beyond threshold. In practice SOG changes, and real decisions will trigger when altVMG is meaningfully larger.
