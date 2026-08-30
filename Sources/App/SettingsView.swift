import AppKit
import SwiftUI

enum AppPreferences {
    static let showBatteryChartKey = "showBatteryChart"
    static let showEstimatedRemainingKey = "showEstimatedRemaining"
}

struct SettingsView: View {
    @ObservedObject var helperRegistration: HelperRegistration
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

            HelperSettingsView(registration: helperRegistration)
                .tabItem {
                    Label("Charge Control", systemImage: "battery.75percent")
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

private struct HelperSettingsView: View {
    @ObservedObject var registration: HelperRegistration

    var body: some View {
        Form {
            Section("Privileged Helper") {
                LabeledContent("Status", value: registration.statusDescription)

                Text("The helper is only required for charge-limit controls. Battery monitoring and history work without it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let error = registration.operationError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Install Helper") {
                        registration.install()
                    }
                    .disabled(!registration.canInstall)

                    Button("Unregister Helper", role: .destructive) {
                        registration.unregister()
                    }
                    .disabled(!registration.canUnregister)

                    if registration.status == .requiresApproval {
                        Button("Open Login Items") {
                            registration.openLoginItems()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                registration.refresh()
                try? await Task.sleep(for: .seconds(1))
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
