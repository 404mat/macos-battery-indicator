import AppKit
import BatteryCore
import BatteryUI
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var batteryTitleLabel: NSTextField?
    private var percentLabel: NSTextField?
    private var elapsedTimeTitleLabel: NSTextField?
    private var elapsedTimeLabel: NSTextField?
    private var estimatedRemainingTitleLabel: NSTextField?
    private var estimatedRemainingValueLabel: NSTextField?
    private var headerView: NSView?
    private var headerRows: [(label: NSTextField, value: NSTextField)] = []
    private var graphMenuItem: NSMenuItem?
    private var graphSeparatorItem: NSMenuItem?
    private let model = BatteryAppModel()
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
            AppPreferences.showEstimatedRemainingKey: true,
        ])
        setUpStatusItem()

        model.$snapshot
            .sink { [weak self] snapshot in
                self?.apply(snapshot)
            }
            .store(in: &cancellables)

        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: BatteryStatusImage.statusItemLength)
        item.menu = buildMenu()
        statusItem = item

        guard let button = item.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        updateStatusItemImage(level: model.snapshot.state.level, mode: model.snapshot.state.chargingMode)
    }

    private func updateStatusItemImage(level: Int, mode: ChargingMode) {
        statusItem?.button?.image = BatteryStatusImage.make(level: level, mode: mode)
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
        let percent = makeLabel(percentDescription, font: .boldSystemFont(ofSize: 13))
        let elapsedTitle = makeLabel("Elapsed Time", font: .systemFont(ofSize: 12), secondary: true)
        let elapsedValue = makeLabel(model.snapshot.metrics.elapsedTimeDescription ?? "–", font: .systemFont(ofSize: 12), secondary: true)
        let estimatedTitle = makeLabel("Time to empty", font: .systemFont(ofSize: 12), secondary: true)
        let estimatedValue = makeLabel(model.snapshot.metrics.estimatedRemainingDescription ?? "–", font: .systemFont(ofSize: 12), secondary: true)

        [title, percent, elapsedTitle, elapsedValue, estimatedTitle, estimatedValue].forEach(container.addSubview)
        batteryTitleLabel = title
        percentLabel = percent
        elapsedTimeTitleLabel = elapsedTitle
        elapsedTimeLabel = elapsedValue
        estimatedRemainingTitleLabel = estimatedTitle
        estimatedRemainingValueLabel = estimatedValue
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
            estimatedTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: HeaderMetrics.inset),
            estimatedTitle.topAnchor.constraint(equalTo: elapsedTitle.bottomAnchor, constant: HeaderMetrics.rowSpacing),
            estimatedValue.centerYAnchor.constraint(equalTo: estimatedTitle.centerYAnchor),
            estimatedValue.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -HeaderMetrics.inset),
            estimatedValue.leadingAnchor.constraint(greaterThanOrEqualTo: estimatedTitle.trailingAnchor, constant: HeaderMetrics.minColumnGap),
        ])
        updateEstimatedRemainingVisibility(
            UserDefaults.standard.bool(forKey: AppPreferences.showEstimatedRemainingKey)
        )
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
        let hostingView = NSHostingView(rootView: BatteryGraphMenuContent(model: model))
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
        updateEstimatedRemainingVisibility(
            UserDefaults.standard.bool(forKey: AppPreferences.showEstimatedRemainingKey)
        )
        model.refresh()
    }

    @objc private func openSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(window.contentView)
    }

    private func makeSettingsWindow() -> NSWindow {
        let settingsView = SettingsView(
            onChartVisibilityChange: { [weak self] isVisible in
                self?.updateChartVisibility(isVisible)
            },
            onEstimatedRemainingVisibilityChange: { [weak self] isVisible in
                self?.updateEstimatedRemainingVisibility(isVisible)
            }
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsView.contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
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

    private func updateEstimatedRemainingVisibility(_ isVisible: Bool) {
        estimatedRemainingTitleLabel?.isHidden = !isVisible
        estimatedRemainingValueLabel?.isHidden = !isVisible

        guard let batteryTitleLabel, let percentLabel,
              let elapsedTimeTitleLabel, let elapsedTimeLabel else { return }

        headerRows = [(batteryTitleLabel, percentLabel), (elapsedTimeTitleLabel, elapsedTimeLabel)]
        if isVisible, let estimatedRemainingTitleLabel, let estimatedRemainingValueLabel {
            headerRows.append((estimatedRemainingTitleLabel, estimatedRemainingValueLabel))
        }
        updateHeaderContentSize()
    }

    private var percentDescription: String {
        let state = model.snapshot.state
        return state.chargingMode == .error ? "N/A" : "\(state.level)%"
    }

    private func apply(_ snapshot: BatterySnapshot) {
        let state = snapshot.state
        percentLabel?.stringValue = state.chargingMode == .error ? "N/A" : "\(state.level)%"
        elapsedTimeLabel?.stringValue = snapshot.metrics.elapsedTimeDescription ?? "–"
        estimatedRemainingValueLabel?.stringValue = snapshot.metrics.estimatedRemainingDescription ?? "–"
        updateStatusItemImage(level: state.level, mode: state.chargingMode)
        updateHeaderContentSize()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}

private struct BatteryGraphMenuContent: View {
    @ObservedObject var model: BatteryAppModel

    var body: some View {
        BatteryGraphView(graph: model.snapshot.graph)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
