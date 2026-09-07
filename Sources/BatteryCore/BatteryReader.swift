import Foundation
import IOKit
import IOKit.ps

public protocol BatteryReading: AnyObject {
    func read() -> BatteryState
}

public final class BatteryReader: BatteryReading {
    // Apple does not expose the native charge limit through IOPowerSources.
    // On supported Macs, AppleSmartBattery publishes an active limiter as bit
    // 24 of its NotChargingReason bit field.
    private static let chargeLimitReason: UInt64 = 1 << 24

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
            let isPausedAtChargeLimit = isPluggedIn
                && !isCharging
                && Self.isNativeChargeLimitActive()
            let mode: ChargingMode = if isCharging {
                .charging
            } else if isPausedAtChargeLimit {
                .paused
            } else if isPluggedIn {
                .pluggedIn
            } else {
                .discharging
            }
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

    private static func isNativeChargeLimitActive() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }

        guard
            let chargerData = IORegistryEntryCreateCFProperty(
                service,
                "ChargerData" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any],
            let notChargingReason = chargerData["NotChargingReason"] as? NSNumber
        else { return false }

        return notChargingReason.uint64Value & chargeLimitReason != 0
    }
}
