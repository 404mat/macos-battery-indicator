import AppKit
import SwiftUI

enum AppPreferences {
    static let showBatteryChartKey = "showBatteryChart"
    static let showEstimatedRemainingKey = "showEstimatedRemaining"
}

struct SettingsView: View {
    static let contentSize = NSSize(width: 780, height: 500)

    let onChartVisibilityChange: (Bool) -> Void
    let onEstimatedRemainingVisibilityChange: (Bool) -> Void

    @State private var selection: SettingsPage? = .menuBar

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Battery Indicator"
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                AppIdentityView(appName: appName)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 16, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Section("Settings") {
                    ForEach(SettingsPage.allCases) { page in
                        SidebarSettingsRow(page: page)
                            .tag(page)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selection ?? .menuBar {
                case .menuBar:
                    MenuSettingsView(
                        onChartVisibilityChange: onChartVisibilityChange,
                        onEstimatedRemainingVisibilityChange: onEstimatedRemainingVisibilityChange
                    )
                case .charging:
                    NativeChargeLimitSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case menuBar
    case charging
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .menuBar: "Menu Bar"
        case .charging: "Charging"
        case .about: "About"
        }
    }

    var iconName: String {
        switch self {
        case .menuBar: "menu-bar"
        case .charging: "charging"
        case .about: "about"
        }
    }
}

private struct SidebarSettingsRow: View {
    let page: SettingsPage

    var body: some View {
        Label {
            Text(page.title)
        } icon: {
            SidebarIcon(name: page.iconName)
        }
    }
}

private struct SidebarIcon: View {
    let name: String

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct AppIdentityView: View {
    let appName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(appName)
                .font(.headline)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NativeChargeLimitSettingsView: View {
    private static let chargingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Battery-Settings.extension?charging"
    )!

    var body: some View {
        SettingsPageContainer(
            title: "Charging",
            subtitle: "Control your Mac's battery charging limit."
        ) {
            SettingsGroup(title: "Charging Limit") {
                Text("macOS manages charging limits natively. Choose a maximum charge level from 80% to 100% in Battery settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)

                Divider()

                HStack {
                    Button("Open Charging Settings") {
                        NSWorkspace.shared.open(Self.chargingSettingsURL)
                    }
                    .accessibilityLabel("Open Charging Settings")

                    Spacer()
                }
                .padding(12)
            }
        }
    }
}

private struct MenuSettingsView: View {
    @AppStorage(AppPreferences.showBatteryChartKey) private var showBatteryChart = true
    @AppStorage(AppPreferences.showEstimatedRemainingKey) private var showEstimatedRemaining = true

    let onChartVisibilityChange: (Bool) -> Void
    let onEstimatedRemainingVisibilityChange: (Bool) -> Void

    var body: some View {
        SettingsPageContainer(
            title: "Menu Bar",
            subtitle: "Choose the information shown in the battery menu."
        ) {
            SettingsGroup(title: "Menu Content") {
                SettingsSwitchRow(title: "Show battery chart", isOn: $showBatteryChart)

                Divider()

                SettingsSwitchRow(title: "Show time to empty", isOn: $showEstimatedRemaining)
            }
        }
        .onChange(of: showBatteryChart) { _, newValue in
            onChartVisibilityChange(newValue)
        }
        .onChange(of: showEstimatedRemaining) { _, newValue in
            onEstimatedRemainingVisibilityChange(newValue)
        }
    }
}

private struct AboutSettingsView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Battery Indicator"
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    var body: some View {
        SettingsPageContainer(
            title: "About",
            subtitle: "macOS Battery Indicator"
        ) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)

                Text(appName)
                    .font(.title3.weight(.semibold))

                Text("Version \(version)")
                    .foregroundStyle(.secondary)

                Text("A lightweight battery monitor for your menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }
}

private struct SettingsPageContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsSwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
