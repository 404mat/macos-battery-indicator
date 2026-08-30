import BatteryXPC
import Foundation

final class HelperClient: ChargeControlService {
    private var connection: NSXPCConnection?

    func connect() {
        guard connection == nil else { return }

        let connection = NSXPCConnection(
            machServiceName: BatteryHelperService.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
        connection.setCodeSigningRequirement(BatteryHelperService.helperCodeSigningRequirement)
        connection.invalidationHandler = { [weak self, weak connection] in
            guard let self, self.connection === connection else { return }
            self.connection = nil
        }
        connection.resume()
        self.connection = connection
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    func setChargeLimit(_ percent: Int, completion: @escaping (Error?) -> Void) {
        guard let proxy = proxy(errorHandler: completion) else {
            completion(HelperClientError.notConnected)
            return
        }
        proxy.setChargeLimit(NSNumber(value: percent), reply: completion)
    }

    func disableChargeLimit(completion: @escaping (Error?) -> Void) {
        guard let proxy = proxy(errorHandler: completion) else {
            completion(HelperClientError.notConnected)
            return
        }
        proxy.disableChargeLimit(reply: completion)
    }

    func chargeToFullOnce(completion: @escaping (Error?) -> Void) {
        guard let proxy = proxy(errorHandler: completion) else {
            completion(HelperClientError.notConnected)
            return
        }
        proxy.chargeToFullOnce(reply: completion)
    }

    private func proxy(errorHandler: @escaping (Error) -> Void) -> BatteryHelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler(errorHandler) as? BatteryHelperProtocol
    }
}

private enum HelperClientError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        "The battery helper is not connected."
    }
}
