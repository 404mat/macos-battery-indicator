import AppKit
import BatteryUI
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var percentLabel: NSTextField?
    private var elapsedTimeLabel: NSTextField?
    private var headerView: NSView?
    private var headerRows: [(label: NSTextField, value: NSTextField)] = []
    private var graphMenuItem: NSMenuItem?
    private var graphSeparatorItem: NSMenuItem?
    private let helperClient = HelperClient()
    private let helperRegistration = HelperRegistration()
    private lazy var model = BatteryIndicatorModel(service: helperClient)
    private var cancellables = Set<AnyCancellable>()

    private enum HeaderMetrics {
        static let inset: CGFloat = 15
        static let minColumnGap: CGFloat = 20
        static let topPadding: CGFloat = 8
        static let rowSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 6
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: [
            "NSMenuEnableActionImages": false,
            AppPreferences.showBatteryChartKey: true,
        ])
        setUpStatusItem()

        model.$batteryLevel
            .combineLatest(model.$chargingMode)
            .sink { [weak self] level, mode in
                self?.percentLabel?.stringValue = mode == .error ? "N/A" : "\(level)%"
                self?.updateHeaderContentSize()
            }
            .store(in: &cancellables)

        model.$elapsedTimeDescription
            .sink { [weak self] description in
                self?.elapsedTimeLabel?.stringValue = description ?? "–"
                self?.updateHeaderContentSize()
            }
            .store(in: &cancellables)

        do {
            try helperRegistration.prepare { [weak self] in
                self?.model.start()
            }
        } catch {
            NSLog("Unable to register battery helper: %@", error.localizedDescription)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: BatteryIndicatorView.Metrics.statusItemLength)
        item.menu = buildMenu()
        statusItem = item

        guard let button = item.button else { return }
        button.image = NSImage()
        button.subviews.forEach { $0.removeFromSuperview() }

        let hostingView = NSHostingView(rootView: BatteryIndicatorView(model: model))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem()
        header.view = makeBatteryHeaderView()
        menu.addItem(header)
        menu.addItem(.separator())
        let graphItem = makeGraphItem()
        let graphSeparator = NSMenuItem.separator()
        graphMenuItem = graphItem
        graphSeparatorItem = graphSeparator
        menu.addItem(graphItem)
        menu.addItem(graphSeparator)
        updateChartVisibility(UserDefaults.standard.bool(forKey: AppPreferences.showBatteryChartKey))

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit macOS Battery Indicator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    private func makeBatteryHeaderView() -> NSView {
        let container = NSView(frame: .zero)
        container.autoresizingMask = [.width]

        let title = makeLabel("Battery", font: .boldSystemFont(ofSize: 13))
        let percent = makeLabel(model.percentDescription, font: .boldSystemFont(ofSize: 13))
        let elapsedTitle = makeLabel("Elapsed Time", font: .systemFont(ofSize: 12), secondary: true)
        let elapsedValue = makeLabel("–", font: .systemFont(ofSize: 12), secondary: true)

        [title, percent, elapsedTitle, elapsedValue].forEach(container.addSubview)
        percentLabel = percent
        elapsedTimeLabel = elapsedValue
        headerRows = [(title, percent), (elapsedTitle, elapsedValue)]
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

    private func makeLabel(_ text: String, font: NSFont, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = secondary ? .secondaryLabelColor : .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeGraphItem() -> NSMenuItem {
        let item = NSMenuItem()
        let width = headerView?.frame.width ?? 220
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: BatteryGraphLayout.totalHeight))
        container.autoresizingMask = [.width]
        let hostingView = NSHostingView(rootView: BatteryGraphView(model: model))
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        item.view = container
        return item
    }

    private func updateHeaderContentSize() {
        guard let headerView else { return }
        let rowsWidth = headerRows.map {
            ceil($0.label.intrinsicContentSize.width) + HeaderMetrics.minColumnGap + ceil($0.value.intrinsicContentSize.width)
        }.max() ?? 0
        let rowHeights = headerRows.map { ceil($0.label.intrinsicContentSize.height) }
        let height = HeaderMetrics.topPadding + rowHeights.reduce(0, +)
            + HeaderMetrics.rowSpacing * CGFloat(max(rowHeights.count - 1, 0))
            + HeaderMetrics.bottomPadding
        headerView.setFrameSize(NSSize(width: HeaderMetrics.inset * 2 + rowsWidth, height: height))
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateChartVisibility(UserDefaults.standard.bool(forKey: AppPreferences.showBatteryChartKey))
        model.refreshSnapshot()
    }

    @objc private func openSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeSettingsWindow() -> NSWindow {
        let settingsView = SettingsView { [weak self] isVisible in
            self?.updateChartVisibility(isVisible)
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: settingsView)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func updateChartVisibility(_ isVisible: Bool) {
        graphMenuItem?.isHidden = !isVisible
        graphSeparatorItem?.isHidden = !isVisible
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
