# SailTact

SailTact is a compact SwiftUI iPhone app to help a small sailboat helmsman decide when to tack or jibe by calculating VMG (velocity made good) relative to the true wind.

This repository contains plain Swift source files suitable for editing in VS Code and building in Xcode.

## Project structure

- `Package.swift` - Swift package manifest (open in Xcode or use it as guidance for creating an Xcode project)
- `Sources/App/MainApp.swift` - App entry
- `Sources/App/ContentView.swift` - SwiftUI UI and app logic
- `Sources/App/VMGCalculator.swift` - Pure VMG math utilities (unit tested)
- `Sources/App/LocationManager.swift` - CLLocationManager wrapper publishing navigation data
- `Sources/App/HapticsManager.swift` - CoreHaptics + UIFeedbackGenerator fallback
- `Sources/App/MapView.swift` - SwiftUI wrapper for MKMapView
- `Tests/VMGTests.swift` - XCTest cases for VMG math

## Math explanation

Velocity made good (VMG) is the component of the boat's speed in the direction of the wind. We compute:

VMG = SOG * cos(Δ)

where:
- SOG is speed over ground in m/s.
- Δ is the smallest signed angle between the boat heading and the true wind direction (TWD), expressed in radians.

Sign convention:
- VMG > 0: boat is making progress toward the wind (upwind progress)
- VMG < 0: boat is making progress away from the wind (downwind progress)

Angle utilities in `VMGCalculator.swift`:
- `normalizeDegrees360(_:)` converts any angle to [0, 360).
- `normalizeDegreesSigned(_:)` converts to (-180, 180].
- `smallestSignedAngleDifference(from:to:)` yields the signed difference in degrees in [-180, 180].

Predicted alternative tack/jibe:
- altHeading = normalize(2 * TWD - heading)
- altVMG = SOG * cos(angleBetween(altHeading, TWD))

If altVMG > currentVMG + threshold, the app recommends a tack/jibe.

## Units
- Internal math uses meters per second (m/s).
- UI displays both m/s and knots (1 knot = 0.514444 m/s).

## Haptics
- Preferred: CoreHaptics pattern of two transient pulses at t=0.0s and t=0.2s.
- Fallback: two `UINotificationFeedbackGenerator` notifications spaced by 0.2s.

## Adaptive per-tack SOG averaging (learning)

The app keeps a lightweight, in-memory histogram of recent SOG samples grouped by
TWA bins (default 5°) and tack side (port/starboard). This adapts to the boat,
crew and sea state so predicted performance on the opposite tack is data-driven.

How it works:
- When valid heading, TWD and SOG arrive, the app records the sample into the
	TWA bin corresponding to the absolute TWA (0..180°) and the current tack side.
- For evaluation, the app computes the mirrored heading across the wind (the
	"altHeading") and its TWA magnitude. It looks up the average SOG observed
	previously for that TWA bin on the opposite tack. If available that value is
	used as predictedSOG for computing altVMG; otherwise the current SOG is used.

This simple adaptive approach is robust (bounded memory, tunable bin width and
sample counts) and requires no external boat instrumentation.

Runtime tuning
----------------
The app exposes two settings so you can tune learning aggressiveness at runtime:

- TWA bin width (degrees) — controls the angular resolution of the histogram (default 5°).
- Max samples per bin — controls how much recent data is retained per bin/tack (default 50).

Adjust these from the in-app Settings sheet under "Learning (SOG history)".

## Permissions & Info.plist keys
Add or ensure the following keys with user-facing strings are present in your app's `Info.plist`:

- `NSLocationWhenInUseUsageDescription` - e.g. "Location required to compute speed, heading and waypoint bearings for sailing navigation."
- `NSLocationAlwaysAndWhenInUseUsageDescription` (optional) - only if you require background location.
- `NSLocationAlwaysUsageDescription` (deprecated but sometimes requested on older SDKs).
- `NSLocationTemporaryUsageDescriptionDictionary` (optional for precise wording during permission flows)
- `NSMotionUsageDescription` - if you rely on motion for heading assistance (optional)

Privacy note: Location data is collected locally on the device and used only for navigation in the app. The app does not upload location data.

## Build & Run (Xcode)

To build and run on a simulator or device:

1. Open `SailTact.xcodeproj` (if you created an Xcode project) or open this folder in Xcode and add a new iOS App target that includes the files in `Sources/App`.
2. In Xcode, select a signing team for the app target (required to run on a real device).
3. Ensure `Info.plist` contains the location permission keys above.
4. Build & run on a device or simulator (note: GPS + heading data is limited on Simulator; tests and UI function will work).

Important: Building in VS Code is for editing only — you must use Xcode to run on device/simulator.

## Tests
The `Tests/VMGTests.swift` file contains unit tests for the VMG math. Run tests in Xcode's Test navigator or `Product -> Test`.

## Troubleshooting
- If VMG reads as zero, ensure you have provided TWD/TWA and the device has a valid heading.
- CLLocation speed can be `-1` when not available; code treats that as unknown and displays 0 for UI convenience.
- CoreHaptics may not be available on older devices — fallback happens automatically.

## Example run log (simulated)
See the `EXAMPLE_RUN_LOG` section below in this README.

## Notes & possible improvements
- Background evaluation & alerts could be added with BackgroundTasks if needed.
- Add a small calibration screen for TWA sign conventions if users prefer the opposite sign.

---

