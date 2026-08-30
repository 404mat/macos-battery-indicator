import Combine
import ServiceManagement

final class HelperRegistration: ObservableObject {
    static let propertyListName = "com.mathias.BatteryIndicator.helper.plist"

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var operationError: String?

    private let service = SMAppService.daemon(plistName: propertyListName)

    init() {
        status = service.status
    }

    var statusDescription: String {
        switch status {
        case .enabled:
            return "Installed and enabled"
        case .requiresApproval:
            return "Installed; approval required"
        case .notRegistered:
            return "Not installed"
        case .notFound:
            return "Helper unavailable in this build"
        @unknown default:
            return "Unknown"
        }
    }

    var canInstall: Bool {
        status == .notRegistered
    }

    var canUnregister: Bool {
        status == .enabled || status == .requiresApproval
    }

    func refresh() {
        status = service.status
    }

    func install() {
        operationError = nil
        do {
            try service.register()
            refresh()
            if status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            operationError = error.localizedDescription
            refresh()
        }
    }

    func unregister() {
        operationError = nil
        do {
            try service.unregister()
            refresh()
        } catch {
            operationError = error.localizedDescription
            refresh()
        }
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
