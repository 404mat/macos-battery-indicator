import BatteryCore
import BatteryData
import Foundation

final class LocalBatteryService: BatteryService {
    var onStateChange: ((BatteryState) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private static let retentionInterval: TimeInterval = 13 * 3600

    private let store: BatteryStore
    private var history: BatteryHistory
    private var state = BatteryState.unavailable()
    private var isConnected = false
    private lazy var monitor = BatteryMonitor(reader: BatteryReader()) { [weak self] state in
        self?.publish(state)
    }

    init(store: BatteryStore = BatteryStore()) {
        self.store = store
        history = store.load()
    }

    func connect() {
        guard !isConnected else { return }
        isConnected = true
        monitor.start()
        onConnectionChange?(true)
    }

    func disconnect() {
        guard isConnected else { return }
        monitor.stop()
        isConnected = false
        onConnectionChange?(false)
    }

    func fetchSnapshot(completion: @escaping (Result<BatterySnapshot, Error>) -> Void) {
        completion(.success(makeSnapshot()))
    }

    private func publish(_ state: BatteryState) {
        self.state = state
        history.append(
            BatterySample(state: state),
            retaining: Self.retentionInterval,
            now: state.timestamp
        )
        try? store.save(history)
        onStateChange?(state)
    }

    private func makeSnapshot() -> BatterySnapshot {
        BatterySnapshot(
            state: state,
            graph: history.graph(now: state.timestamp),
            metrics: BatteryMetrics(history: history, currentState: state)
        )
    }
}
