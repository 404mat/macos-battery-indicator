import Foundation
import IOKit.ps

public protocol BatteryReading: AnyObject {
    func read() -> BatteryState
}

public final class BatteryReader: BatteryReading {
    public init() {}

    public func read() -> BatteryState {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard
                let info = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as NSDictionary? as? [String: Any],
                info[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType as String,
                let capacity = info[kIOPSCurrentCapacityKey as String] as? Int
            else { continue }

            let powerSourceState = info[kIOPSPowerSourceStateKey as String] as? String
            let isPluggedIn = powerSourceState == kIOPSACPowerValue as String
            let isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false
            let mode: ChargingMode = isCharging ? .charging : (isPluggedIn ? .pluggedIn : .discharging)
            let timeToEmpty = info[kIOPSTimeToEmptyKey as String] as? Int

            return BatteryState(
                level: capacity,
                chargingMode: mode,
                isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                timeToEmptyMinutes: timeToEmpty
            )
        }

        return .unavailable()
    }
}
