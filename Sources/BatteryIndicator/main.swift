import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let batteryPercent = "100%"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🔋 \(batteryPercent)"
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

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
        NSHostingView(
            rootView: HStack {
                Text("Battery")
                Spacer(minLength: 20)
                Text(batteryPercent)
            }
            .fontWeight(.bold)
            .frame(width: 220)
            .padding(.horizontal, 15)
            .padding(.vertical, 6)
        )
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
