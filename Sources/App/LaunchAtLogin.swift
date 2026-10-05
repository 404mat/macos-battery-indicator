import Foundation
import ServiceManagement

/// Manages the app's registration as a login item with the system.
enum LaunchAtLogin {
    enum Status: Equatable {
        case enabled
        case requiresApproval
        case notRegistered
        case failed(String)
    }

    static var isEnabled: Bool {
        currentStatus == .enabled
    }

    static var currentStatus: Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .notRegistered
        @unknown default: .notRegistered
        }
    }

    /// Registers or unregisters the main app bundle as a login item and
    /// returns the resulting status.
    static func setEnabled(_ enabled: Bool) -> Status {
        let current = currentStatus
        if (enabled && current == .enabled) || (!enabled && current == .notRegistered) {
            return current
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return .failed(error.localizedDescription)
        }
        return currentStatus
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
