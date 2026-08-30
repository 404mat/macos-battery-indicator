import AppKit
import SwiftUI

enum AppPreferences {
    static let showBatteryChartKey = "showBatteryChart"
    static let showEstimatedRemainingKey = "showEstimatedRemaining"
}

struct SettingsView: View {
    let onChartVisibilityChange: (Bool) -> Void
    let onEstimatedRemainingVisibilityChange: (Bool) -> Void

    var body: some View {
        TabView {
            MenuSettingsView(
                onChartVisibilityChange: onChartVisibilityChange,
                onEstimatedRemainingVisibilityChange: onEstimatedRemainingVisibilityChange
            )
                .tabItem {
                    Label("Menu", systemImage: "menubar.rectangle")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .padding(20)
        .frame(width: 440, height: 250)
    }
}

private struct MenuSettingsView: View {
    @AppStorage(AppPreferences.showBatteryChartKey) private var showBatteryChart = true
    @AppStorage(AppPreferences.showEstimatedRemainingKey) private var showEstimatedRemaining = true

    let onChartVisibilityChange: (Bool) -> Void
    let onEstimatedRemainingVisibilityChange: (Bool) -> Void

    var body: some View {
        Form {
            Section("Sections") {
                Toggle("Show battery chart in the menu", isOn: $showBatteryChart)
                Toggle("Show time to empty in the menu", isOn: $showEstimatedRemaining)
            }
        }
        .formStyle(.grouped)
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
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            Text(appName)
                .font(.title2.weight(.semibold))

            Text("Version \(version)")
                .foregroundStyle(.secondary)

            Text("A lightweight battery monitor for your menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
