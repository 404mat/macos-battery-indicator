import BatteryCore
import BatteryData
import BatteryXPC
import Foundation

public final class BatteryIndicatorModel: ObservableObject {
    @Published public private(set) var batteryLevel = 0
    @Published public private(set) var chargingMode = ChargingMode.error
    @Published public private(set) var batteryGraph: BatteryGraph?
    @Published public private(set) var elapsedTimeDescription: String?
    @Published public private(set) var isHelperConnected = false

    public var percentDescription: String {
        chargingMode == .error ? "N/A" : "\(batteryLevel)%"
    }

    private let service: BatteryService

    public init(service: BatteryService) {
        self.service = service
        service.onStateChange = { [weak self] payload in
            self?.receiveState(payload)
        }
        service.onConnectionChange = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isHelperConnected = connected
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
            guard case .success(let payload) = result,
                  let snapshot = try? BatteryXPCCodec.decode(BatterySnapshot.self, from: payload)
            else { return }
            DispatchQueue.main.async {
                self?.apply(snapshot.state)
                self?.batteryGraph = snapshot.graph
                self?.elapsedTimeDescription = snapshot.metrics.elapsedTimeDescription
            }
        }
    }

    private func receiveState(_ payload: Data) {
        guard let state = try? BatteryXPCCodec.decode(BatteryState.self, from: payload) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.apply(state)
        }
    }

    private func apply(_ state: BatteryState) {
        batteryLevel = state.level
        chargingMode = state.chargingMode
    }
}
