// Sources/App/LocationManager.swift
import Foundation
import CoreLocation
import Combine
import CoreLocation
import MapKit

/// PublishedStatus holds live navigation data measured by CLLocationManager.
public struct PublishedStatus {
    public var coordinate: CLLocationCoordinate2D?
    public var sog_mps: Double? // speed over ground in m/s
    public var cog_deg: Double?  // course over ground (degrees)
    public var heading_deg: Double? // device heading (degrees) if available
    public var timestamp: Date?
}

/// LocationManager wraps CLLocationManager and publishes live navigation data for SwiftUI.
final public class LocationManager: NSObject, ObservableObject {
    // MARK: - Published properties
    @Published public private(set) var status = PublishedStatus()
    @Published public private(set) var startWaypoint: CLLocationCoordinate2D?
    @Published public private(set) var distanceToWaypoint_m: Double?
    @Published public private(set) var bearingToWaypoint_deg: Double?

    // CLLocationManager
    private let manager = CLLocationManager()

    // update interval / accuracy handling
    private var lastUpdate: Date? = nil

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1.0 // meters
        manager.headingFilter = 1.0 // degrees
        // For reasonable UI updates: reduce battery impact if needed
        manager.activityType = .fitness
        requestPermissionsIfNeeded()
    }

    /// Request permission if not determined.
    public func requestPermissionsIfNeeded() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        manager.startUpdatingLocation()
    }

    /// Set the start waypoint to current coordinate.
    public func setStartWaypoint() {
        guard let coord = status.coordinate else { return }
        startWaypoint = coord
        updateWaypointInfo()
    }

    private func updateWaypointInfo() {
        guard let wp = startWaypoint, let coord = status.coordinate else {
            distanceToWaypoint_m = nil
            bearingToWaypoint_deg = nil
            return
        }
        distanceToWaypoint_m = VMGCalculator.distanceMeters(from: coord, to: wp)
        bearingToWaypoint_deg = VMGCalculator.bearingDegrees(from: coord, to: wp)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Update at reasonable UI interval (1s-2s)
        let now = Date()
        if let last = lastUpdate, now.timeIntervalSince(last) < 0.8 {
            // skip too-frequent updates
        } else {
            lastUpdate = now
            DispatchQueue.main.async {
                self.status.coordinate = loc.coordinate
                self.status.sog_mps = loc.speed >= 0 ? loc.speed : nil // CLLocation speed can be -1 when invalid
                self.status.cog_deg = loc.course >= 0 ? loc.course : nil
                self.status.timestamp = loc.timestamp
                self.updateWaypointInfo()
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            // Use trueHeading if valid, otherwise magnetic
            let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            self.status.heading_deg = heading
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }
}
