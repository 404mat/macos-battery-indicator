import BatteryCore
import Foundation

public struct BatteryMetrics: Codable, Equatable, Sendable {
    public let sampleCount: Int
    public let averageLevel: Double?
    public let elapsedTimeDescription: String?

    public init(history: BatteryHistory, currentState: BatteryState) {
        sampleCount = history.samples.count
        if history.samples.isEmpty {
            averageLevel = nil
        } else {
            averageLevel = Double(history.samples.reduce(0) { $0 + $1.level }) / Double(history.samples.count)
        }

        guard currentState.chargingMode != .error else {
            elapsedTimeDescription = nil
            return
        }
        let matching = history.samples.reversed().prefix {
            $0.chargingMode == currentState.chargingMode
        }
        guard let oldest = matching.last else {
            elapsedTimeDescription = nil
            return
        }
        let seconds = max(0, Int(currentState.timestamp.timeIntervalSince(oldest.timestamp)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        switch (hours, minutes) {
        case (0, 0): elapsedTimeDescription = "0 mins"
        case (0, 1): elapsedTimeDescription = "1 min"
        case (0, let minutes): elapsedTimeDescription = "\(minutes) mins"
        case (1, 0): elapsedTimeDescription = "1 hr"
        case (let hours, 0): elapsedTimeDescription = "\(hours) hrs"
        case (let hours, let minutes):
            elapsedTimeDescription = "\(hours) \(hours == 1 ? "hr" : "hrs"), \(minutes) \(minutes == 1 ? "min" : "mins")"
        }
    }
}
