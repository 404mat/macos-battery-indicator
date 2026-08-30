import BatteryCore
import Foundation

public struct BatteryMetrics: Codable, Equatable, Sendable {
    public let sampleCount: Int
    public let averageLevel: Double?
    public let elapsedTimeDescription: String?
    public let estimatedRemainingDescription: String?

    public init(history: BatteryHistory, currentState: BatteryState) {
        sampleCount = history.samples.count
        if history.samples.isEmpty {
            averageLevel = nil
        } else {
            averageLevel = Double(history.samples.reduce(0) { $0 + $1.level }) / Double(history.samples.count)
        }

        guard currentState.chargingMode != .error else {
            elapsedTimeDescription = nil
            estimatedRemainingDescription = nil
            return
        }
        let matching = history.samples.reversed().prefix {
            $0.chargingMode == currentState.chargingMode
        }
        guard let oldest = matching.last else {
            elapsedTimeDescription = nil
            estimatedRemainingDescription = Self.estimatedRemainingDescription(for: currentState)
            return
        }
        let seconds = max(0, Int(currentState.timestamp.timeIntervalSince(oldest.timestamp)))
        elapsedTimeDescription = Self.durationDescription(totalMinutes: seconds / 60)
        estimatedRemainingDescription = Self.estimatedRemainingDescription(for: currentState)
    }

    public static func estimatedRemainingDescription(for state: BatteryState) -> String? {
        guard state.chargingMode == .discharging,
              let minutes = state.timeToEmptyMinutes else { return nil }
        if minutes < 0 { return "Calculating…" }
        guard minutes > 0 else { return nil }
        return durationDescription(totalMinutes: minutes)
    }

    private static func durationDescription(totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, 0): return "0 mins"
        case (0, 1): return "1 min"
        case (0, let minutes): return "\(minutes) mins"
        case (1, 0): return "1 hr"
        case (let hours, 0): return "\(hours) hrs"
        case (let hours, let minutes):
            return "\(hours) \(hours == 1 ? "hr" : "hrs"), \(minutes) \(minutes == 1 ? "min" : "mins")"
        }
    }
}
