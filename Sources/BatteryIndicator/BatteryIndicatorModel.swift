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

    var elapsedTimeDescription: String? {
        guard
            let systemstats_get_battery_charge_graph = SystemStats.batteryChargeGraph,
            let batteryChargeGraph = systemstats_get_battery_charge_graph()
                .retain().takeRetainedValue() as? [String: Any],
            let rawBatteryStates = batteryChargeGraph["battery_states"] as? [Bool],
            let batteryTimes = batteryChargeGraph["battery_times"] as? [UInt],
            rawBatteryStates.count == batteryTimes.count,
            let lastTime = batteryTimes.last
        else {
            return nil
        }
        let seconds = Int(clamping: lastTime)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        switch (hours, minutes) {
        case (0, 0):
            return "0 mins"
        case (0, let m):
            return m == 1 ? "1 min" : "\(m) mins"
        case (let h, 0):
            return h == 1 ? "1 hr" : "\(h) hrs"
        case (let h, let m):
            return "\(h == 1 ? "1 hr" : "\(h) hrs"), \(m == 1 ? "1 min" : "\(m) mins")"
        }
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
