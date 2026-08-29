import Foundation
import IOKit.ps

public final class BatteryMonitor {
    public typealias StateHandler = (BatteryState) -> Void

    private let reader: BatteryReading
    private let handler: StateHandler
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?

    public init(reader: BatteryReading, handler: @escaping StateHandler) {
        self.reader = reader
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start(sampleInterval: TimeInterval = 60) {
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ rawContext in
            guard let rawContext else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(rawContext).takeUnretainedValue()
            monitor.publishCurrentState()
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.publishCurrentState()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        publishCurrentState()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    public func publishCurrentState() {
        handler(reader.read())
    }
}
