import Foundation

public enum BatteryHelperService {
    public static let machServiceName = "com.mathias.BatteryIndicator.helper"
    public static let helperCodeSigningRequirement = "identifier \"com.mathias.BatteryIndicator.helper\""
    public static let appCodeSigningRequirement = "identifier \"com.mathias.BatteryIndicator\""
}

@objc public protocol BatteryHelperProtocol {
    func setChargeLimit(_ percent: NSNumber, reply: @escaping (NSError?) -> Void)
    func disableChargeLimit(reply: @escaping (NSError?) -> Void)
    func chargeToFullOnce(reply: @escaping (NSError?) -> Void)
}

public protocol ChargeControlService: AnyObject {
    func connect()
    func disconnect()
    func setChargeLimit(_ percent: Int, completion: @escaping (Error?) -> Void)
    func disableChargeLimit(completion: @escaping (Error?) -> Void)
    func chargeToFullOnce(completion: @escaping (Error?) -> Void)
}
