import BatteryCore
import BatteryData
import Combine
import Foundation

struct BatterySnapshot {
    let state: BatteryState
    let graph: BatteryGraph?
    let metrics: BatteryMetrics
}

/// The application's single source of truth for battery data.
final class BatteryAppModel: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot

    private static let retentionInterval: TimeInterval = 13 * 3600

    private let store: BatteryStore
    private var history: BatteryHistory
    private var state: BatteryState
    private lazy var monitor = BatteryMonitor(reader: BatteryReader()) { [weak self] state in
        self?.record(state)
    }

    init(store: BatteryStore = BatteryStore()) {
        self.store = store
        history = store.load()
        state = .unavailable()
        snapshot = Self.makeSnapshot(state: state, history: history)
    }

    func start() { monitor.start() }
    func stop() { monitor.stop() }
    func refresh() { monitor.publishCurrentState() }

    private func record(_ state: BatteryState) {
        self.state = state
        history.append(BatterySample(state: state), retaining: Self.retentionInterval, now: state.timestamp)
        try? store.save(history)
        snapshot = Self.makeSnapshot(state: state, history: history)
    }

    private static func makeSnapshot(state: BatteryState, history: BatteryHistory) -> BatterySnapshot {
        BatterySnapshot(
            state: state,
            graph: history.graph(now: state.timestamp),
            metrics: BatteryMetrics(history: history, currentState: state)
        )
    }
}
