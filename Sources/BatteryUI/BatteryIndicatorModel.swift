import BatteryCore
import BatteryData
import Foundation

public final class BatteryIndicatorModel: ObservableObject {
    @Published public private(set) var batteryLevel = 0
    @Published public private(set) var chargingMode = ChargingMode.error
    @Published public private(set) var batteryGraph: BatteryGraph?
    @Published public private(set) var elapsedTimeDescription: String?
    @Published public private(set) var estimatedRemainingDescription: String?
    @Published public private(set) var isConnected = false

    public var percentDescription: String {
        chargingMode == .error ? "N/A" : "\(batteryLevel)%"
    }

    private let service: BatteryService

    public init(service: BatteryService) {
        self.service = service
        service.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.apply(state)
            }
        }
        service.onConnectionChange = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isConnected = connected
                if connected {
                    self?.refreshSnapshot()
                } else {
                    self?.chargingMode = .error
                }
            }
        }
    }

    public func start() {
        service.connect()
    }

    public func stop() {
        service.disconnect()
    }

    public func refreshSnapshot() {
        service.fetchSnapshot { [weak self] result in
            guard case .success(let snapshot) = result else { return }
            DispatchQueue.main.async {
                self?.apply(snapshot.state)
                self?.batteryGraph = snapshot.graph
                self?.elapsedTimeDescription = snapshot.metrics.elapsedTimeDescription
            }
        }
    }

    private func apply(_ state: BatteryState) {
        batteryLevel = state.level
        chargingMode = state.chargingMode
        estimatedRemainingDescription = BatteryMetrics.estimatedRemainingDescription(for: state)
    }
}
