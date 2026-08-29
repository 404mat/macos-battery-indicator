import Foundation

public protocol ChargeControllerProtocol: AnyObject {
    func setChargeLimit(_ percent: Int) throws
    func disableChargeLimit() throws
    func chargeToFullOnce() throws
}

public enum ChargeControllerError: LocalizedError {
    case unsupported
    case invalidLimit(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Charge control is not supported on this Mac yet."
        case .invalidLimit(let limit):
            return "The charge limit must be between 20 and 100 percent; received \(limit)."
        }
    }
}
