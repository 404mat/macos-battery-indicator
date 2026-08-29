import BatteryCore
import Foundation

public struct BatterySample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let level: Int
    public let chargingMode: ChargingMode
    public let isLowPowerModeEnabled: Bool

    public init(state: BatteryState) {
        timestamp = state.timestamp
        level = state.level
        chargingMode = state.chargingMode
        isLowPowerModeEnabled = state.isLowPowerModeEnabled
    }
}
