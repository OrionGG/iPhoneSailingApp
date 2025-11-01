// Sources/App/VMGCalculator.swift
import Foundation
import CoreLocation

/// VMGCalculator provides pure functions for navigation math: angle normalization,
/// bearing/distance between coordinates, VMG computation and predicted altVMG.
public struct VMGCalculator {
    /// Convert degrees to radians.
    public static func deg2rad(_ deg: Double) -> Double { deg * .pi / 180.0 }

    /// Convert radians to degrees.
    public static func rad2deg(_ rad: Double) -> Double { rad * 180.0 / .pi }

    /// Normalize angle to [0, 360).
    public static func normalizeDegrees360(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        return a
    }

    /// Normalize angle to signed range (-180, 180]. Useful for smallest signed difference.
    public static func normalizeDegreesSigned(_ angle: Double) -> Double {
        var a = normalizeDegrees360(angle)
        if a > 180 { a -= 360 }
        return a
    }

    /// Smallest signed angle difference from a -> b in degrees in range [-180, 180].
    /// Positive means rotate clockwise from a to b (i.e., b is to the right of a).
    public static func smallestSignedAngleDifference(from a: Double, to b: Double) -> Double {
        let diff = normalizeDegreesSigned(b - a)
        return diff
    }

    /// Haversine distance between two coordinates in meters.
    /// Uses CLLocation's distance method for robustness.
    public static func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let b = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return a.distance(from: b)
    }

    /// Bearing from `from` to `to` in degrees, 0 = North, increasing clockwise (0..360).
    /// Formula: initial bearing (forward azimuth).
    public static func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = deg2rad(from.latitude)
        let lon1 = deg2rad(from.longitude)
        let lat2 = deg2rad(to.latitude)
        let lon2 = deg2rad(to.longitude)
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let brng = atan2(y, x)
        let deg = normalizeDegrees360(rad2deg(brng) + 360) // ensure positive
        return deg
    }

    /// Compute VMG (velocity made good) given speed over ground (m/s), boat heading (deg), and true wind direction (deg).
    /// VMG = SOG * cos(delta), where delta is the smallest signed angle between heading and TWD, in radians.
    /// VMG sign: positive = towards the wind (upwind progress), negative = away from the wind (downwind progress).
    public static func vmg(sog_mps: Double, headingDeg: Double, twdDeg: Double) -> Double {
        let deltaDeg = smallestSignedAngleDifference(from: headingDeg, to: twdDeg)
        let deltaRad = deg2rad(deltaDeg)
        return sog_mps * cos(deltaRad)
    }

    /// Compute predicted altVMG if the boat were to mirror the heading across the wind:
    /// altHeading = normalize(2*TWD - heading)
    public static func predictedAltVMG(sog_mps: Double, headingDeg: Double, twdDeg: Double) -> (altHeading: Double, altVMG: Double) {
        let altHeading = normalizeDegrees360(2.0 * twdDeg - headingDeg)
        let altVMG = vmg(sog_mps: sog_mps, headingDeg: altHeading, twdDeg: twdDeg)
        return (altHeading, altVMG)
    }
}
