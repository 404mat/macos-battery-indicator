import Foundation

public enum ChargingMode: String, Codable, Equatable, Sendable {
    case charging
    case paused
    case pluggedIn
    case discharging
    case error
}

public struct BatteryState: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let level: Int
    public let chargingMode: ChargingMode
    public let isLowPowerModeEnabled: Bool
    public let timeToEmptyMinutes: Int?

    public init(
        timestamp: Date = Date(),
        level: Int,
        chargingMode: ChargingMode,
        isLowPowerModeEnabled: Bool,
        timeToEmptyMinutes: Int? = nil
    ) {
        self.timestamp = timestamp
        self.level = min(max(level, 0), 100)
        self.chargingMode = chargingMode
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.timeToEmptyMinutes = timeToEmptyMinutes
    }

    public static func unavailable(at date: Date = Date()) -> BatteryState {
        BatteryState(
            timestamp: date,
            level: 0,
            chargingMode: .error,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            timeToEmptyMinutes: nil
        )
    }
}
