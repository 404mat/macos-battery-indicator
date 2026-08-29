import BatteryXPC
import Foundation

final class HelperClient: NSObject, BatteryService, BatteryHelperClientProtocol {
    var onStateChange: ((Data) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private var connection: NSXPCConnection?

    func connect() {
        guard connection == nil else { return }

        let connection = NSXPCConnection(
            machServiceName: BatteryHelperService.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: BatteryHelperClientProtocol.self)
        connection.exportedObject = self
        connection.setCodeSigningRequirement(BatteryHelperService.helperCodeSigningRequirement)
        connection.interruptionHandler = { [weak self] in
            self?.onConnectionChange?(false)
        }
        connection.invalidationHandler = { [weak self, weak connection] in
            guard let self, self.connection === connection else { return }
            self.connection = nil
            self.onConnectionChange?(false)
        }
        connection.resume()
        self.connection = connection
        onConnectionChange?(true)
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
        onConnectionChange?(false)
    }

    func fetchSnapshot(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let proxy = proxy(errorHandler: { completion(.failure($0)) }) else {
            completion(.failure(HelperClientError.notConnected))
            return
        }
        proxy.fetchSnapshot { data, error in
            if let error { completion(.failure(error)) }
            else if let data { completion(.success(data)) }
            else { completion(.failure(HelperClientError.emptyResponse)) }
        }
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

    func batteryStateDidChange(_ encodedState: Data) {
        onStateChange?(encodedState)
    }

    private func proxy(errorHandler: @escaping (Error) -> Void) -> BatteryHelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler(errorHandler) as? BatteryHelperProtocol
    }
}

private enum HelperClientError: LocalizedError {
    case notConnected
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConnected: return "The battery helper is not connected."
        case .emptyResponse: return "The battery helper returned an empty response."
        }
    }
}
