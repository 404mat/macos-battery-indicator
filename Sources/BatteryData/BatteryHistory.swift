import BatteryCore
import Foundation

public struct BatteryGraph: Codable, Equatable, Sendable {
    public static let window: TimeInterval = 12 * 3600

    public enum PowerHighlightKind: String, Codable, Equatable, Sendable {
        case charging
        case lowPower
    }

    public struct LevelSegment: Codable, Equatable, Sendable {
        public let start: Date
        public let end: Date
        public let level: Int

        public init(start: Date, end: Date, level: Int) {
            self.start = start
            self.end = end
            self.level = level
        }
    }

    public struct PowerSegment: Codable, Equatable, Sendable {
        public let start: Date
        public let end: Date
        public let kind: PowerHighlightKind

        public init(start: Date, end: Date, kind: PowerHighlightKind) {
            self.start = start
            self.end = end
            self.kind = kind
        }
    }

    public let windowStart: Date
    public let levelSegments: [LevelSegment]
    public let highlightSegments: [PowerSegment]

    public init(windowStart: Date, levelSegments: [LevelSegment], highlightSegments: [PowerSegment]) {
        self.windowStart = windowStart
        self.levelSegments = levelSegments
        self.highlightSegments = highlightSegments
    }

    public func level(at date: Date) -> Int? {
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

public struct BatteryHistory: Codable, Equatable, Sendable {
    public private(set) var samples: [BatterySample]

    public init(samples: [BatterySample] = []) {
        self.samples = samples.sorted { $0.timestamp < $1.timestamp }
    }

    public mutating func append(_ sample: BatterySample, retaining interval: TimeInterval, now: Date) {
        samples.append(sample)
        let cutoff = now.addingTimeInterval(-interval)
        samples.removeAll { $0.timestamp < cutoff }
    }

    public func graph(now: Date = Date()) -> BatteryGraph? {
        let windowStart = now.addingTimeInterval(-BatteryGraph.window)
        let visible = samples.filter { $0.timestamp >= windowStart && $0.timestamp <= now }
        guard !visible.isEmpty else { return nil }

        let levels = visible.enumerated().map { index, sample in
            BatteryGraph.LevelSegment(
                start: sample.timestamp,
                end: index + 1 < visible.count ? visible[index + 1].timestamp : now,
                level: sample.level
            )
        }

        var highlights: [BatteryGraph.PowerSegment] = []
        for kind in [BatteryGraph.PowerHighlightKind.charging, .lowPower] {
            var activeStart: Date?
            for (index, sample) in visible.enumerated() {
                let active = kind == .charging
                    ? sample.chargingMode == .charging
                    : sample.isLowPowerModeEnabled
                let end = index + 1 < visible.count ? visible[index + 1].timestamp : now
                if active, activeStart == nil { activeStart = sample.timestamp }
                if !active, let start = activeStart {
                    highlights.append(.init(start: start, end: sample.timestamp, kind: kind))
                    activeStart = nil
                }
                if index == visible.count - 1, let start = activeStart {
                    highlights.append(.init(start: start, end: end, kind: kind))
                }
            }
        }

        return BatteryGraph(
            windowStart: windowStart,
            levelSegments: levels,
            highlightSegments: highlights.sorted { $0.start < $1.start }
        )
    }
}
