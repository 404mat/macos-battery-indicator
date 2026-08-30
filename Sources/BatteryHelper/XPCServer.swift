import BatteryCore
import BatteryXPC
import Foundation

final class XPCServer: NSObject, BatteryHelperProtocol {
    private let chargeController: ChargeControllerProtocol

    init(chargeController: ChargeControllerProtocol) {
        self.chargeController = chargeController
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
        connection.exportedInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
        connection.exportedObject = server
        connection.resume()
        return true
    }
}
