// Sources/App/SOGHistory.swift
import Foundation

/// Tack side enumeration: which side the wind is on relative to the boat.
/// - Note: We define tack side by the signed angle from heading -> TWD (degrees):
///   - If signedAngle > 0 -> wind is to the port side -> tack = .port
///   - If signedAngle < 0 -> wind is to the starboard side -> tack = .starboard
public enum TackSide: String, Codable {
    case port
    case starboard
}

/// SOGHistory maintains recent SOG samples binned by TWA (True Wind Angle) and tack side.
/// It provides averaged SOG estimates for a given TWA bin and tack, used to predict
/// how fast the boat typically goes on the opposite tack at a similar TWA.
public final class SOGHistory: ObservableObject {
    /// bin width in degrees for grouping TWA samples (e.g. 5° bins)
    /// Exposed as a published var so it can be tuned at runtime from Settings.
    @Published public var binWidthDeg: Double
    /// maximum stored samples per bin to keep memory bounded
    /// Exposed as a published var so it can be tuned at runtime from Settings.
    @Published public var maxSamplesPerBin: Int

    // internal storage: key = "binIndex|tack" -> array of recent speeds (m/s)
    private var storage: [String: [Double]] = [:]
    private let storageQueue = DispatchQueue(label: "SOGHistory.queue")

    public init(binWidthDeg: Double = 5.0, maxSamplesPerBin: Int = 50) {
        self.binWidthDeg = binWidthDeg
        self.maxSamplesPerBin = maxSamplesPerBin
    }

    private func key(forBinIndex idx: Int, tack: TackSide) -> String {
        return "\(idx)|\(tack.rawValue)"
    }

    private func binIndex(forTWA twa: Double) -> Int {
        // twa expected in [0, 180]; map to integer bin index (floor)
        let clamped = max(0.0, min(180.0, twa))
        return Int(floor(clamped / binWidthDeg))
    }

    /// Record a SOG sample (m/s) for a given TWA (degrees, magnitude) and tack side.
    /// This is non-blocking and thread-safe.
    public func recordSample(twa: Double, tack: TackSide, sog_mps: Double) {
        let idx = binIndex(forTWA: abs(twa))
        let k = key(forBinIndex: idx, tack: tack)
        storageQueue.async {
            var arr = self.storage[k] ?? []
            arr.append(sog_mps)
            if arr.count > self.maxSamplesPerBin {
                arr.removeFirst(arr.count - self.maxSamplesPerBin)
            }
            self.storage[k] = arr
        }
    }

    /// Return the average speed (m/s) for the TWA bin nearest the provided twa and the given tack.
    /// Returns nil if there is no data for that bin+tack.
    public func averageSpeed(forTWADegrees twa: Double, tack: TackSide) -> Double? {
        let idx = binIndex(forTWA: abs(twa))
        let k = key(forBinIndex: idx, tack: tack)
        var result: Double?
        storageQueue.sync {
            if let arr = storage[k], !arr.isEmpty {
                let sum = arr.reduce(0.0, +)
                result = sum / Double(arr.count)
            } else {
                result = nil
            }
        }
        return result
    }

    /// For debugging/testing: clear history.
    public func clear() {
        storageQueue.async {
            self.storage.removeAll()
        }
    }
}
