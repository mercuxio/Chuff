import AppKit
import ServiceManagement

// Ported from Squiggle's LaunchAtLogin.swift — same states, same decisions,
// same on-screen notes.

/// What the system will do at the next login, as this app can see it. Four
/// states, not a Bool: `needsApproval` (registered but switched off by the
/// user in System Settings) and `unavailable` (no .app bundle) aren't "off".
enum LoginItemState: Equatable {
    case on
    case off
    case needsApproval
    case unavailable

    init(status: SMAppService.Status, bundled: Bool) {
        guard bundled else { self = .unavailable; return }
        switch status {
        case .enabled: self = .on
        case .notRegistered: self = .off
        // A correctly signed bundle reports `.notFound` until its first
        // successful registration — that's "off", not "unavailable"
        // (Squiggle's fix for the greyed-out checkbox).
        case .notFound: self = .off
        case .requiresApproval: self = .needsApproval
        @unknown default: self = .unavailable
        }
    }

    /// Ticked only when the app will actually launch.
    var isOn: Bool { self == .on }
    var isEnabled: Bool { self != .unavailable }
    var showsSystemSettingsButton: Bool { self == .needsApproval }

    /// `nil` for the two states the checkbox already explains.
    var note: String? {
        switch self {
        case .on, .off: return nil
        case .needsApproval: return "Turned off in System Settings."
        case .unavailable: return "Available when Railway Monitor is running from an app bundle."
        }
    }
}

/// Why a registration attempt didn't take — domain and code only, never the
/// localized description (which can contain file paths).
struct LoginItemFailure: Equatable {
    let domain: String
    let code: Int

    init(_ error: Error) {
        let bridged = error as NSError
        domain = bridged.domain
        code = bridged.code
    }
}

struct LoginItemOutcome: Equatable {
    let state: LoginItemState
    let failure: LoginItemFailure?
}

enum LoginItemAction: Equatable {
    case register, unregister, openSystemSettings, nothing
}

enum LaunchAtLogin {
    static func read() -> LoginItemState {
        LoginItemState(status: SMAppService.mainApp.status, bundled: isBundledApp(.main))
    }

    /// Performs the action and returns the state afterwards, read back from
    /// the system rather than assumed. A refusal is reported, not swallowed,
    /// so the checkbox never silently springs back with no reason shown.
    @MainActor
    static func apply(_ action: LoginItemAction) -> LoginItemOutcome {
        var failure: LoginItemFailure?
        switch action {
        case .register:
            do { try SMAppService.mainApp.register() } catch { failure = LoginItemFailure(error) }
        case .unregister:
            do { try SMAppService.mainApp.unregister() } catch { failure = LoginItemFailure(error) }
        case .openSystemSettings:
            SMAppService.openSystemSettingsLoginItems()
        case .nothing:
            break
        }
        return LoginItemOutcome(state: read(), failure: failure)
    }

    static func isBundledApp(_ bundle: Bundle) -> Bool {
        bundle.bundleURL.pathExtension == "app"
    }

    /// What clicking the checkbox should do given the system's current state.
    static func action(desired: Bool, current: LoginItemState) -> LoginItemAction {
        switch current {
        case .unavailable: return .nothing
        case .on: return desired ? .nothing : .unregister
        case .off: return desired ? .register : .nothing
        // register() on an already-registered service throws and wouldn't
        // clear the user's own switch; show them where the switch is.
        case .needsApproval: return desired ? .openSystemSettings : .unregister
        }
    }

    /// The note under the checkbox: the refusal (if any) joined to the
    /// state's own sentence.
    static func note(for state: LoginItemState, failure: LoginItemFailure?) -> String? {
        guard let failure else { return state.note }
        let refusal = "macOS refused the change (\(failure.domain) \(failure.code))."
        guard let existing = state.note else { return refusal }
        return "\(refusal) \(existing)"
    }
}
