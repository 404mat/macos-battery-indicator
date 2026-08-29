import Darwin
import Foundation
import IOKit.ps

enum ChargingMode {
    case charging
    case discharging
    case error
}

final class BatteryIndicatorModel: ObservableObject {
    @Published private(set) var batteryLevel: Int = 100
    @Published private(set) var chargingMode: ChargingMode = .discharging

    var percentDescription: String {
        chargingMode == .error ? "N/A" : "\(batteryLevel)%"
    }

    private let elapsedTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter
    }()

    var elapsedTimeDescription: String? {
        guard
            let systemstats_get_battery_charge_graph = SystemStats.batteryChargeGraph,
            let batteryChargeGraph = systemstats_get_battery_charge_graph().takeRetainedValue() as? [String: Any],
            let rawBatteryStates = batteryChargeGraph["battery_states"] as? [Bool],
            let batteryTimes = batteryChargeGraph["battery_times"] as? [UInt],
            rawBatteryStates.count == batteryTimes.count,
            let lastTime = batteryTimes.last
        else {
            return nil
        }
        return elapsedTimeFormatter.string(from: Double(lastTime))
    }

    private var timer: Timer?

    func startPolling(every interval: TimeInterval = 10) {
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        guard let powerSource = readPowerSource() else {
            batteryLevel = 0
            chargingMode = .error
            return
        }
        batteryLevel = powerSource.level
        chargingMode = powerSource.isPluggedIn ? .charging : .discharging
    }

    private func readPowerSource() -> (level: Int, isPluggedIn: Bool)? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard
                let info = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as NSDictionary? as? [String: Any],
                info[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType as String,
                let capacity = info[kIOPSCurrentCapacityKey as String] as? Int
            else { continue }
            let state = info[kIOPSPowerSourceStateKey as String] as? String
            return (capacity, state == kIOPSACPowerValue as String)
        }
        return nil
    }
}

private enum SystemStats {
    static let batteryChargeGraph: (@convention(c) () -> Unmanaged<NSDictionary>)? = {
        var pointer: UnsafeMutableRawPointer?
        if let handle = dlopen("/usr/lib/libsystemstats.dylib", RTLD_LAZY) {
            pointer = dlsym(handle, "systemstats_get_battery_charge_graph")
            dlclose(handle)
        }
        return unsafeBitCast(pointer, to: (@convention(c) () -> Unmanaged<NSDictionary>)?.self)
    }()
}
