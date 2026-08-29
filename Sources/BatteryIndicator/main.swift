import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var percentLabel: NSTextField?
    private var elapsedTimeLabel: NSTextField?
    private var hostingView: NSHostingView<BatteryIndicatorView>?
    private let model = BatteryIndicatorModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: ["NSMenuEnableActionImages": false])
        setUpStatusItem()

        model.$batteryLevel
            .combineLatest(model.$chargingMode)
            .sink { [weak self] level, mode in
                self?.percentLabel?.stringValue = mode == .error ? "N/A" : "\(level)%"
                self?.elapsedTimeLabel?.stringValue = self?.model.elapsedTimeDescription ?? ""
            }
            .store(in: &cancellables)

        model.startPolling()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 32)
        item.menu = buildMenu()
        statusItem = item

        guard let button = item.button else { return }
        let hostingView = NSHostingView(rootView: BatteryIndicatorView(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 32, height: 24)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        button.image = NSImage()
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)
        self.hostingView = hostingView
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
        let quit = NSMenuItem(title: "Quit macOS Battery Indicator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func makeBatteryHeaderView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 53))

        let title = NSTextField(labelWithString: "Battery")
        title.font = .boldSystemFont(ofSize: 13)
        title.translatesAutoresizingMaskIntoConstraints = false

        let percent = NSTextField(labelWithString: model.percentDescription)
        percent.font = .boldSystemFont(ofSize: 13)
        percent.translatesAutoresizingMaskIntoConstraints = false

        let elapsedTitle = NSTextField(labelWithString: "Elapsed Time")
        elapsedTitle.font = .systemFont(ofSize: 12)
        elapsedTitle.textColor = .secondaryLabelColor
        elapsedTitle.translatesAutoresizingMaskIntoConstraints = false

        let elapsedValue = NSTextField(labelWithString: model.elapsedTimeDescription)
        elapsedValue.font = .systemFont(ofSize: 12)
        elapsedValue.textColor = .secondaryLabelColor
        elapsedValue.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(percent)
        container.addSubview(elapsedTitle)
        container.addSubview(elapsedValue)
        percentLabel = percent
        elapsedTimeLabel = elapsedValue

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            percent.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            percent.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            percent.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 20),

            elapsedTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            elapsedTitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            elapsedValue.centerYAnchor.constraint(equalTo: elapsedTitle.centerYAnchor),
            elapsedValue.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            elapsedValue.leadingAnchor.constraint(greaterThanOrEqualTo: elapsedTitle.trailingAnchor, constant: 20),
        ])

        return container
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
        percentLabel?.stringValue = model.percentDescription
        elapsedTimeLabel?.stringValue = model.elapsedTimeDescription
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
