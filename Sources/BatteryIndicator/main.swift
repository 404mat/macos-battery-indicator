import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var percentLabel: NSTextField?
    private var hostingView: NSHostingView<StatusItemRootView>?
    private var showPercentageItem: NSMenuItem?
    private var showPercentageNextToItem: NSMenuItem?
    private let model = BatteryIndicatorModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()

        model.$batteryLevel
            .combineLatest(model.$chargingMode)
            .sink { [weak self] level, mode in
                self?.percentLabel?.stringValue = mode == .error ? "N/A" : "\(level)%"
            }
            .store(in: &cancellables)

        model.startPolling()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = buildMenu()
        statusItem = item

        guard let button = item.button else { return }
        let hostingView = NSHostingView(
            rootView: StatusItemRootView(
                model: model,
                onSizeChange: { [weak self] size in
                    self?.resizeStatusItem(to: size)
                }
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 38, height: 24)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        button.image = NSImage()
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)
        self.hostingView = hostingView
    }

    private func resizeStatusItem(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let width = ceil(size.width)
        guard statusItem?.length != width else { return }
        statusItem?.length = width
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem()
        header.view = makeBatteryHeaderView()
        menu.addItem(header)
        menu.addItem(.separator())

        let showPercentage = NSMenuItem(
            title: "Show Percentage",
            action: #selector(toggleShowPercentage(_:)),
            keyEquivalent: ""
        )
        showPercentage.target = self
        menu.addItem(showPercentage)
        showPercentageItem = showPercentage

        let showNextTo = NSMenuItem(
            title: "Show Percentage Next to Icon",
            action: #selector(toggleShowPercentageNextTo(_:)),
            keyEquivalent: ""
        )
        showNextTo.target = self
        menu.addItem(showNextTo)
        showPercentageNextToItem = showNextTo

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

        let percent = NSTextField(labelWithString: model.percentDescription)
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

    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
        showPercentageItem?.state = model.showPercentage ? .on : .off
        showPercentageNextToItem?.state = model.showPercentageNextToIndicator ? .on : .off
        percentLabel?.stringValue = model.percentDescription
    }

    @objc private func toggleShowPercentage(_ sender: NSMenuItem) {
        model.showPercentage.toggle()
        sender.state = model.showPercentage ? .on : .off
    }

    @objc private func toggleShowPercentageNextTo(_ sender: NSMenuItem) {
        model.showPercentageNextToIndicator.toggle()
        sender.state = model.showPercentageNextToIndicator ? .on : .off
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
