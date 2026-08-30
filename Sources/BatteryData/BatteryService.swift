import BatteryCore
import Foundation

public struct BatterySnapshot: Equatable, Sendable {
    public let state: BatteryState
    public let graph: BatteryGraph?
    public let metrics: BatteryMetrics

    public init(state: BatteryState, graph: BatteryGraph?, metrics: BatteryMetrics) {
        self.state = state
        self.graph = graph
        self.metrics = metrics
    }
}

public protocol BatteryService: AnyObject {
    var onStateChange: ((BatteryState) -> Void)? { get set }
    var onConnectionChange: ((Bool) -> Void)? { get set }

    func connect()
    func disconnect()
    func fetchSnapshot(completion: @escaping (Result<BatterySnapshot, Error>) -> Void)
}
