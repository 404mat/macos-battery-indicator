import AppKit
import SwiftUI

enum AppPreferences {
    static let showBatteryChartKey = "showBatteryChart"
}

struct SettingsView: View {
    let onChartVisibilityChange: (Bool) -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(onChartVisibilityChange: onChartVisibilityChange)
                .tabItem {
                    Label("General", systemImage: "gearshape")
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

private struct GeneralSettingsView: View {
    @AppStorage(AppPreferences.showBatteryChartKey) private var showBatteryChart = true

    let onChartVisibilityChange: (Bool) -> Void

    var body: some View {
        Form {
            Section("Sections") {
                Toggle("Show battery chart in the menu", isOn: $showBatteryChart)
            }
        }
        .formStyle(.grouped)
        .onChange(of: showBatteryChart) { newValue in
            onChartVisibilityChange(newValue)
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
