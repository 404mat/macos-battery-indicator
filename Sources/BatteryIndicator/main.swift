import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var percentLabel: NSTextField?
    private var elapsedTimeLabel: NSTextField?
    private var headerView: NSView?
    private var headerRows: [(label: NSTextField, value: NSTextField)] = []
    private var hostingView: NSHostingView<BatteryIndicatorView>?
    private let model = BatteryIndicatorModel()
    private var cancellables = Set<AnyCancellable>()
    private var isMenuOpen = false
    private var lastElapsedTimeDescription: String?
    private let elapsedTimeQueue = DispatchQueue(label: "elapsed-time", qos: .userInitiated)

    private enum HeaderMetrics {
        static let inset: CGFloat = 15
        static let minColumnGap: CGFloat = 20
        static let topPadding: CGFloat = 8
        static let rowSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 6
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: ["NSMenuEnableActionImages": false])
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
        let container = NSView(frame: .zero)
        container.autoresizingMask = [.width]

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

        let elapsedValue = NSTextField(labelWithString: model.elapsedTimeDescription ?? "–")
        elapsedValue.font = .systemFont(ofSize: 12)
        elapsedValue.textColor = .secondaryLabelColor
        elapsedValue.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(percent)
        container.addSubview(elapsedTitle)
        container.addSubview(elapsedValue)
        percentLabel = percent
        elapsedTimeLabel = elapsedValue
        headerRows = [
            (label: title, value: percent),
            (label: elapsedTitle, value: elapsedValue),
        ]
        headerView = container

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: HeaderMetrics.inset),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: HeaderMetrics.topPadding),
            percent.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            percent.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -HeaderMetrics.inset),
            percent.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: HeaderMetrics.minColumnGap),

            elapsedTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: HeaderMetrics.inset),
            elapsedTitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: HeaderMetrics.rowSpacing),
            elapsedValue.centerYAnchor.constraint(equalTo: elapsedTitle.centerYAnchor),
            elapsedValue.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -HeaderMetrics.inset),
            elapsedValue.leadingAnchor.constraint(greaterThanOrEqualTo: elapsedTitle.trailingAnchor, constant: HeaderMetrics.minColumnGap),
        ])

        updateHeaderContentSize()
        return container
    }

    private func updateHeaderContentSize() {
        guard let headerView else { return }
        let rowsWidth = headerRows
            .map { ceil($0.label.intrinsicContentSize.width) + HeaderMetrics.minColumnGap + ceil($0.value.intrinsicContentSize.width) }
            .max() ?? 0
        let rowHeights = headerRows.map { ceil($0.label.intrinsicContentSize.height) }
        let height = HeaderMetrics.topPadding
            + rowHeights.reduce(0, +)
            + HeaderMetrics.rowSpacing * CGFloat(rowHeights.count - 1)
            + HeaderMetrics.bottomPadding
        headerView.setFrameSize(NSSize(width: HeaderMetrics.inset * 2 + rowsWidth, height: height))
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        model.refresh()
        percentLabel?.stringValue = model.percentDescription
        elapsedTimeLabel?.stringValue = lastElapsedTimeDescription ?? "–"
        updateHeaderContentSize()
        elapsedTimeQueue.async { [weak self] in
            guard let description = self?.model.elapsedTimeDescription else { return }
            DispatchQueue.main.async {
                self?.applyElapsedTimeDescription(description)
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func applyElapsedTimeDescription(_ description: String?) {
        lastElapsedTimeDescription = description
        elapsedTimeLabel?.stringValue = description ?? "–"
        guard !isMenuOpen else { return }
        updateHeaderContentSize()
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
