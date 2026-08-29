import BatteryCore
import BatteryData
import BatteryXPC
import Foundation

final class XPCServer: NSObject, BatteryHelperProtocol {
    private let chargeController: ChargeControllerProtocol
    private let recorder: HistoryRecorder
    private var state = BatteryState.unavailable()
    private var connections: [UUID: NSXPCConnection] = [:]

    init(chargeController: ChargeControllerProtocol, recorder: HistoryRecorder) {
        self.chargeController = chargeController
        self.recorder = recorder
    }

    func addConnection(_ connection: NSXPCConnection, id: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.connections[id] = connection
        }
    }

    func removeConnection(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.connections[id] = nil
        }
    }

    func publish(_ state: BatteryState) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.state = state
        recorder.record(state)
        guard let payload = try? BatteryXPCCodec.encode(state) else { return }

        for connection in connections.values {
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in } as? BatteryHelperClientProtocol
            proxy?.batteryStateDidChange(payload)
        }
    }

    func fetchSnapshot(reply: @escaping (Data?, NSError?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                reply(try BatteryXPCCodec.encode(makeSnapshot()), nil)
            } catch {
                reply(nil, error as NSError)
            }
        }
    }

    private func makeSnapshot() -> BatterySnapshot {
        BatterySnapshot(
            state: state,
            graph: recorder.history.graph(now: state.timestamp),
            metrics: BatteryMetrics(history: recorder.history, currentState: state)
        )
    }

    func setChargeLimit(_ percent: NSNumber, reply: @escaping (NSError?) -> Void) {
        perform(reply: reply) { try self.chargeController.setChargeLimit(percent.intValue) }
    }

    func disableChargeLimit(reply: @escaping (NSError?) -> Void) {
        perform(reply: reply) { try self.chargeController.disableChargeLimit() }
    }

    func chargeToFullOnce(reply: @escaping (NSError?) -> Void) {
        perform(reply: reply) { try self.chargeController.chargeToFullOnce() }
    }

    private func perform(reply: @escaping (NSError?) -> Void, operation: @escaping () throws -> Void) {
        DispatchQueue.main.async {
            do {
                try operation()
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }
}

final class XPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let server: XPCServer

    init(server: XPCServer) {
        self.server = server
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let id = UUID()
        connection.exportedInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
        connection.exportedObject = server
        connection.remoteObjectInterface = NSXPCInterface(with: BatteryHelperClientProtocol.self)
        connection.invalidationHandler = { [weak server] in server?.removeConnection(id: id) }
        connection.interruptionHandler = { [weak server] in server?.removeConnection(id: id) }
        server.addConnection(connection, id: id)
        connection.resume()
        return true
    }
}
