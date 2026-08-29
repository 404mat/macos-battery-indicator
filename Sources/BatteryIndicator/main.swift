import AppKit
import IOKit.ps

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var percentLabel: NSTextField?
    private var batteryTimer: Timer?
    private var batteryPercent = "N/A"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = buildMenu()
        statusItem = item

        refreshBatteryStatus()

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshBatteryStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem()
        header.view = makeBatteryHeaderView()
        menu.addItem(header)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func makeBatteryHeaderView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))

        let title = NSTextField(labelWithString: "Battery")
        title.font = .boldSystemFont(ofSize: 13)
        title.translatesAutoresizingMaskIntoConstraints = false

        let percent = NSTextField(labelWithString: batteryPercent)
        percent.font = .boldSystemFont(ofSize: 13)
        percent.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(percent)
        percentLabel = percent

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            title.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            percent.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            percent.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            percent.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 20),
        ])

        return container
    }

    private func refreshBatteryStatus() {
        guard let capacity = readBatteryPercentage() else { return }
        batteryPercent = "\(capacity)%"
        statusItem?.button?.title = "🔋 \(batteryPercent)"
        percentLabel?.stringValue = batteryPercent
    }

    private func readBatteryPercentage() -> Int? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as NSDictionary? as? [String: Any],
                  (info[kIOPSTypeKey as String] as? String) == kIOPSInternalBatteryType as String,
                  let capacity = info[kIOPSCurrentCapacityKey as String] as? Int
            else { continue }
            return capacity
        }
        return nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshBatteryStatus()
    }

    @objc private func openSettings() {
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Battery Indicator Settings"
            window.delegate = self
            window.center()

            let settingsLabel = NSTextField(labelWithString: "Settings")
            settingsLabel.font = .boldSystemFont(ofSize: 16)

            let hint = NSTextField(wrappingLabelWithString: "This is a placeholder settings page. Battery settings will live here.")
            hint.frame = NSRect(x: 20, y: 60, width: 320, height: 60)

            let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 240))
            settingsLabel.frame = NSRect(x: 20, y: 190, width: 200, height: 24)
            container.addSubview(settingsLabel)
            container.addSubview(hint)
            window.contentView = container

            settingsWindow = window
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
