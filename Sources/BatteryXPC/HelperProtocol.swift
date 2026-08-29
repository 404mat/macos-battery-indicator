import Foundation

public enum BatteryHelperService {
    public static let machServiceName = "com.mathias.BatteryIndicator.helper"
    public static let helperCodeSigningRequirement = "identifier \"com.mathias.BatteryIndicator.helper\""
    public static let appCodeSigningRequirement = "identifier \"com.mathias.BatteryIndicator\""
}

@objc public protocol BatteryHelperProtocol {
    func fetchSnapshot(reply: @escaping (Data?, NSError?) -> Void)
    func setChargeLimit(_ percent: NSNumber, reply: @escaping (NSError?) -> Void)
    func disableChargeLimit(reply: @escaping (NSError?) -> Void)
    func chargeToFullOnce(reply: @escaping (NSError?) -> Void)
}

@objc public protocol BatteryHelperClientProtocol {
    func batteryStateDidChange(_ encodedState: Data)
}

public protocol BatteryService: AnyObject {
    var onStateChange: ((Data) -> Void)? { get set }
    var onConnectionChange: ((Bool) -> Void)? { get set }

    func connect()
    func disconnect()
    func fetchSnapshot(completion: @escaping (Result<Data, Error>) -> Void)
    func setChargeLimit(_ percent: Int, completion: @escaping (Error?) -> Void)
    func disableChargeLimit(completion: @escaping (Error?) -> Void)
    func chargeToFullOnce(completion: @escaping (Error?) -> Void)
}
