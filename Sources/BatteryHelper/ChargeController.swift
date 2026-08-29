import BatteryCore

final class ChargeController: ChargeControllerProtocol {
    func setChargeLimit(_ percent: Int) throws {
        guard (20...100).contains(percent) else {
            throw ChargeControllerError.invalidLimit(percent)
        }
        throw ChargeControllerError.unsupported
    }

    func disableChargeLimit() throws {
        throw ChargeControllerError.unsupported
    }

    func chargeToFullOnce() throws {
        throw ChargeControllerError.unsupported
    }
}
