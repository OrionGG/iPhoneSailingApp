// Tests/VMGTests.swift
import XCTest
@testable import App
import CoreLocation

final class VMGTests: XCTestCase {
    /// Upwind case: heading toward wind -> positive VMG expected when heading points at wind.
    func testUpwindVMGPositive() {
        let sog = 5.0 // m/s
        let heading = 0.0 // heading north
        let twd = 10.0 // wind from 10° (slightly starboard)
        let v = VMGCalculator.vmg(sog_mps: sog, headingDeg: heading, twdDeg: twd)
        XCTAssertGreaterThan(v, 0)
    }

    /// Downwind case: heading away from wind -> VMG negative expected.
    func testDownwindVMGNegative() {
        let sog = 4.0
        let heading = 180.0
        let twd = 0.0
        let v = VMGCalculator.vmg(sog_mps: sog, headingDeg: heading, twdDeg: twd)
        XCTAssertLessThan(v, 0)
    }

    /// Perpendicular case: heading 90° to wind -> VMG near 0.
    func testPerpendicularVMGZero() {
        let sog = 3.0
        let heading = 90.0
        let twd = 0.0
        let v = VMGCalculator.vmg(sog_mps: sog, headingDeg: heading, twdDeg: twd)
        XCTAssertEqual(round(v * 1000) / 1000.0, 0.0, "VMG should be ~0 for perpendicular")
    }

    /// Symmetric tack improvement: for a given heading, the mirrored heading across the wind should produce same magnitude VMG but mirrored sign where appropriate.
    func testSymmetricTackImprovement() {
        let sog = 5.0
        let heading = 45.0
        let twd = 0.0
        let current = VMGCalculator.vmg(sog_mps: sog, headingDeg: heading, twdDeg: twd)
        let (altHeading, altVMG) = VMGCalculator.predictedAltVMG(sog_mps: sog, headingDeg: heading, twdDeg: twd)
        // The two VMGs should be equal if symmetric about wind (within floating error)
        XCTAssertEqual(round(current * 1000) / 1000.0, round(altVMG * 1000) / 1000.0)
        // altHeading should be symmetric
        XCTAssertEqual(VMGCalculator.normalizeDegrees360(altHeading), VMGCalculator.normalizeDegrees360(2*twd - heading))
    }
}
