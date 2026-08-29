import BatteryCore
import BatteryData
import BatteryXPC
import Foundation

let server = XPCServer(
    chargeController: ChargeController(),
    recorder: HistoryRecorder()
)
let listenerDelegate = XPCListenerDelegate(server: server)
let listener = NSXPCListener(machServiceName: BatteryHelperService.machServiceName)
listener.setConnectionCodeSigningRequirement(BatteryHelperService.appCodeSigningRequirement)
listener.delegate = listenerDelegate

let monitor = BatteryMonitor(reader: BatteryReader()) { state in
    DispatchQueue.main.async {
        server.publish(state)
    }
}

listener.resume()
monitor.start()
RunLoop.main.run()
