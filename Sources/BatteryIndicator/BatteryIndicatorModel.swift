import Darwin
import Foundation
import IOKit.ps

struct BatteryGraph {
    static let window: TimeInterval = 12 * 3600

    struct LevelSegment: Equatable {
        let start: Date
        let end: Date
        let level: Int
    }

    struct PowerSegment: Equatable {
        let start: Date
        let end: Date
    }

    let windowStart: Date
    let levelSegments: [LevelSegment]
    let acPowerSegments: [PowerSegment]

    func level(at date: Date) -> Int? {
        var lowest = 0
        var highest = levelSegments.count - 1
        var currentLevel: Int?
        while lowest <= highest {
            let middle = (lowest + highest) / 2
            if levelSegments[middle].start <= date {
                currentLevel = levelSegments[middle].level
                lowest = middle + 1
            } else {
                highest = middle - 1
            }
        }
        return currentLevel
    }
}

enum ChargingMode {
    case charging
    case discharging
    case error
}

final class BatteryIndicatorModel: ObservableObject {
    @Published private(set) var batteryLevel: Int = 100
    @Published private(set) var chargingMode: ChargingMode = .discharging
    @Published private(set) var batteryGraph: BatteryGraph?

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
    private let graphQueue = DispatchQueue(label: "battery-graph", qos: .userInitiated)

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

    func refreshBatteryGraph() {
        graphQueue.async { [weak self] in
            guard let graph = Self.readBatteryGraph(now: Date()) else { return }
            DispatchQueue.main.async {
                self?.batteryGraph = graph
            }
        }
    }

    private static func readBatteryGraph(now: Date) -> BatteryGraph? {
        guard
            let systemstats_get_battery_charge_graph = SystemStats.batteryChargeGraph,
            let batteryChargeGraph = systemstats_get_battery_charge_graph()
                .retain().takeRetainedValue() as? [String: Any],
            let rawBatteryStates = batteryChargeGraph["battery_states"] as? [Bool],
            let batteryTimes = batteryChargeGraph["battery_times"] as? [UInt],
            rawBatteryStates.count == batteryTimes.count,
            let rawChargeLevels = batteryChargeGraph["charge_levels"] as? [UInt8],
            let chargeTimes = batteryChargeGraph["charge_times"] as? [UInt],
            rawChargeLevels.count == chargeTimes.count
        else {
            return nil
        }

        guard
            let levelSegments = makeSegments(values: rawChargeLevels.map(Int.init), times: chargeTimes, now: now),
            let powerStateSegments = makeSegments(values: rawBatteryStates, times: batteryTimes, now: now)
        else {
            return nil
        }

        let windowStart = now.addingTimeInterval(-BatteryGraph.window)

        let levelSegmentsInWindow = levelSegments.compactMap { segment -> BatteryGraph.LevelSegment? in
            let start = max(segment.start, windowStart)
            let end = min(segment.end, now)
            guard end > start else { return nil }
            return BatteryGraph.LevelSegment(start: start, end: end, level: segment.value)
        }
        guard !levelSegmentsInWindow.isEmpty else {
            return nil
        }

        var acPowerSegments = [BatteryGraph.PowerSegment]()
        for segment in powerStateSegments where !segment.value {
            let start = max(segment.start, windowStart)
            let end = min(segment.end, now)
            guard end > start else { continue }
            if let last = acPowerSegments.last, start.timeIntervalSince(last.end) < 1 {
                acPowerSegments[acPowerSegments.count - 1] = BatteryGraph.PowerSegment(start: last.start, end: end)
            } else {
                acPowerSegments.append(BatteryGraph.PowerSegment(start: start, end: end))
            }
        }

        return BatteryGraph(
            windowStart: windowStart,
            levelSegments: levelSegmentsInWindow,
            acPowerSegments: acPowerSegments
        )
    }

    private static func makeSegments<T>(
        values: [T],
        times: [UInt],
        now: Date
    ) -> [(start: Date, end: Date, value: T)]? {
        guard values.count == times.count, let latest = times.max() else {
            return nil
        }
        if latest > 100_000_000 {
            let scale: Double = latest > 100_000_000_000 ? 1_000 : 1
            let points = zip(values, times)
                .map { (date: Date(timeIntervalSince1970: Double($1) / scale), value: $0) }
                .sorted { $0.date < $1.date }
            return points.enumerated().map { index, point in
                let end = index + 1 < points.count ? points[index + 1].date : now
                return (start: point.date, end: max(point.date, end), value: point.value)
            }
        }
        var segments = [(start: Date, end: Date, value: T)]()
        segments.reserveCapacity(values.count)
        var end = now
        for (value, time) in zip(values.reversed(), times.reversed()) {
            let start = end.addingTimeInterval(-Double(time))
            segments.append((start: start, end: end, value: value))
            end = start
        }
        return segments.reversed()
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
