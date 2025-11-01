# Info.plist keys (snippet)

Include the following keys and user-facing strings in your app's Info.plist:

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location required to compute speed, heading and waypoint bearings for sailing navigation.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Optional: needed if you want to evaluate VMG while the app is backgrounded.</string>

<key>NSMotionUsageDescription</key>
<string>Motion data used to improve heading estimates.</string>

# Why these are needed
- When In Use: required for CLLocationManager location and course information.
- Motion: helpful if you extend to device motion based heading fusion.

Ensure you edit these strings to match your app's privacy policy.
