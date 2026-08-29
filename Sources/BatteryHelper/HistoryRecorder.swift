import BatteryCore
import BatteryData
import Foundation

final class HistoryRecorder {
    private static let retentionInterval: TimeInterval = 13 * 3600

    private let store: BatteryStore
    private(set) var history: BatteryHistory

    init(store: BatteryStore = BatteryStore()) {
        self.store = store
        history = store.load()
    }

    func record(_ state: BatteryState) {
        history.append(
            BatterySample(state: state),
            retaining: Self.retentionInterval,
            now: state.timestamp
        )
        try? store.save(history)
    }
}
