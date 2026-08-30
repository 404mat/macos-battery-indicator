import BatteryXPC
import Foundation

let server = XPCServer(chargeController: ChargeController())
let listenerDelegate = XPCListenerDelegate(server: server)
let listener = NSXPCListener(machServiceName: BatteryHelperService.machServiceName)
listener.setConnectionCodeSigningRequirement(BatteryHelperService.appCodeSigningRequirement)
listener.delegate = listenerDelegate

listener.resume()
RunLoop.main.run()
