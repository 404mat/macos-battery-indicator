import BatteryCore
import BatteryData
import Foundation

public struct BatterySnapshot: Codable, Equatable, Sendable {
    public let state: BatteryState
    public let graph: BatteryGraph?
    public let metrics: BatteryMetrics

    public init(state: BatteryState, graph: BatteryGraph?, metrics: BatteryMetrics) {
        self.state = state
        self.graph = graph
        self.metrics = metrics
    }
}

public enum BatteryXPCCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
