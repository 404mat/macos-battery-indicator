import Foundation
import ServiceManagement

final class HelperRegistration {
    static let propertyListName = "com.mathias.BatteryIndicator.helper.plist"

    private let service = SMAppService.daemon(plistName: propertyListName)
    private var statusTimer: Timer?

    deinit {
        statusTimer?.invalidate()
    }

    func prepare(onEnabled: @escaping () -> Void) throws {
        switch service.status {
        case .enabled:
            onEnabled()
            return
        case .notRegistered, .notFound:
            do {
                try service.register()
            } catch {
                guard service.status == .requiresApproval else { throw error }
            }
        case .requiresApproval:
            break
        @unknown default:
            throw HelperRegistrationError.unknownStatus
        }

        if service.status == .enabled {
            onEnabled()
            return
        }

        guard service.status == .requiresApproval else {
            throw HelperRegistrationError.unknownStatus
        }

        SMAppService.openSystemSettingsLoginItems()
        observeApproval(onEnabled: onEnabled)
    }

    private func observeApproval(onEnabled: @escaping () -> Void) {
        statusTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard service.status == .enabled else { return }
            timer.invalidate()
            statusTimer = nil
            onEnabled()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }
}

private enum HelperRegistrationError: LocalizedError {
    case unknownStatus

    var errorDescription: String? {
        "The battery helper has an unknown registration status."
    }
}
