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
    @Published var showPercentage = true
    @Published var showPercentageNextToIndicator = false

    var showsPercentageInside: Bool {
        showPercentage && !showPercentageNextToIndicator
    }

    var percentDescription: String {
        chargingMode == .error ? "N/A" : "\(batteryLevel)%"
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
