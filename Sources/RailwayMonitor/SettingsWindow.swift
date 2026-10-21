import AppKit
import SwiftUI
import Combine

/// The Settings window — the same arrangement as Squiggle's
/// `SettingsWindowController`: an AppKit window around a SwiftUI grouped form,
/// opened from the footer's gear, closed by Escape, and kept alive between
/// openings.
@MainActor
final class SettingsWindowController: NSWindowController {
    let model: SettingsModel

    /// `updater` defaults to Sparkle, resolved inside the (main-actor) body
    /// because a default argument is evaluated outside the actor.
    init(store: StatusStore,
         updater: UpdateChecker? = nil,
         version: String? = AppVersion.current) {
        model = SettingsModel(store: store, updater: updater ?? .sparkle, version: version)

        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = .preferredContentSize
        let window = EscapeClosingWindow(contentViewController: hosting)
        // No `.resizable`: the form has one correct size.
        window.styleMask = [.titled, .closable]
        // A titled window always builds all three traffic lights; hide the two
        // dead ones so only close remains (as Squiggle does).
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.title = "Railway Monitor Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowBecameKey),
            name: NSWindow.didBecomeKeyNotification, object: window)
    }

    /// Login Items can be changed in System Settings while this is open.
    @objc private func windowBecameKey() { model.refreshLoginItem() }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("built in code, not a xib") }

    /// Bring the window forward. The app is an agent (no Dock icon), so it
    /// has to activate itself or the window opens behind the front app.
    func present() {
        model.objectWillChange.send()   // re-read Sparkle's preference
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Settings state. `ObservableObject` rather than `@Observable` (which Squiggle
/// uses) to keep this project free of macros.
@MainActor
final class SettingsModel: ObservableObject {
    let store: StatusStore
    let updater: UpdateChecker
    let version: String?
    private var cancellable: AnyCancellable?

    init(store: StatusStore, updater: UpdateChecker, version: String?) {
        self.store = store
        self.updater = updater
        self.version = version
        // The monochrome flag lives in the store (it drives the menubar icon),
        // so pass its changes through to the form.
        cancellable = store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var monochromeIcons: Bool {
        get { store.monochromeIcons }
        set { store.monochromeIcons = newValue }
    }

    /// Hidden entirely when Sparkle can't run (no bundle / no feed).
    var showsUpdates: Bool { updater.isAvailable }

    /// Read through to Sparkle, which owns and persists this preference.
    var checksForUpdatesAutomatically: Bool {
        get { updater.automaticallyChecks() }
        set {
            objectWillChange.send()
            updater.setAutomaticallyChecks(newValue)
        }
    }

    func checkForUpdates() { updater.checkNow() }

    var versionLine: String? { version.map { "Railway Monitor \($0)" } }

    // MARK: Open at Login (as Squiggle)

    @Published private(set) var loginState: LoginItemState = LaunchAtLogin.read()
    @Published private(set) var loginFailure: LoginItemFailure?

    var loginNote: String? { LaunchAtLogin.note(for: loginState, failure: loginFailure) }

    /// Read, never remembered: the user can change this in System Settings
    /// while the window is open, so it's re-read whenever the window comes
    /// forward.
    func refreshLoginItem() {
        loginState = LaunchAtLogin.read()
        loginFailure = nil
    }

    func setLaunchAtLogin(_ wanted: Bool) {
        let action = LaunchAtLogin.action(desired: wanted, current: LaunchAtLogin.read())
        show(LaunchAtLogin.apply(action))
    }

    func openLoginItems() { show(LaunchAtLogin.apply(.openSystemSettings)) }

    private func show(_ outcome: LoginItemOutcome) {
        loginState = outcome.state
        loginFailure = outcome.failure
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                RefreshIntervalSlider(minutes: Binding(
                    get: { model.store.refreshMinutes },
                    set: { model.store.refreshMinutes = $0 }))
            }

            Section {
                Toggle("Monochrome icons", isOn: Binding(
                    get: { model.monochromeIcons },
                    set: { model.monochromeIcons = $0 }))
                Text("Show the menubar status as a symbol — tick, alert, cross — instead of a coloured dot.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Same section and order as Squiggle: Open at Login, then updates.
            Section {
                Toggle("Open at Login", isOn: Binding(
                    get: { model.loginState.isOn },
                    set: { model.setLaunchAtLogin($0) }))
                    .disabled(!model.loginState.isEnabled)
                if let note = model.loginNote {
                    // A refusal is red; the standing states are explanation.
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(model.loginFailure == nil ? Color.secondary : Color.red)
                }
                if model.loginState.showsSystemSettingsButton {
                    Button("Open Login Items…") { model.openLoginItems() }
                }
                // Hidden rather than disabled when Sparkle can't run here.
                if model.showsUpdates {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { model.checksForUpdatesAutomatically },
                        set: { model.checksForUpdatesAutomatically = $0 }))
                    Button("Check for Updates…") { model.checkForUpdates() }
                }
            }

            Section {
                HStack {
                    if let versionLine = model.versionLine {
                        Text(versionLine).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link("Status from status.railway.com", destination: StatusStore.statusPage)
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Refresh every" — a stepped slider over the uneven stops 1, 3, 5, 10
/// minutes. The slider runs over the stop *index* (0…3, step 1), so the stops
/// are evenly spaced and the knob snaps to each; a label sits under each tick.
struct RefreshIntervalSlider: View {
    @Binding var minutes: Int
    private let choices = StatusStore.refreshChoices
    /// Horizontal distance from the slider's edge to its first/last tick —
    /// half the knob's width on macOS.
    private let tickInset: CGFloat = 10

    private var index: Binding<Double> {
        Binding(
            get: { Double(choices.firstIndex(of: minutes) ?? 0) },
            set: { minutes = choices[min(max(Int($0.rounded()), 0), choices.count - 1)] })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Refresh every")
                Spacer()
                Text(minutes == 1 ? "1 minute" : "\(minutes) minutes")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: index, in: 0...Double(choices.count - 1), step: 1)
                .labelsHidden()
            // Tick labels, each centred under its tick.
            GeometryReader { geo in
                let usable = geo.size.width - tickInset * 2
                ForEach(Array(choices.enumerated()), id: \.offset) { i, value in
                    Text("\(value)m")
                        .font(.caption)
                        .foregroundStyle(value == minutes ? .primary : .secondary)
                        .fixedSize()
                        .position(x: tickInset + usable * CGFloat(i) / CGFloat(choices.count - 1),
                                  y: geo.size.height / 2)
                }
            }
            .frame(height: 14)
            Text("Longer intervals use less data and battery; the menubar only greys out after 2½ missed refreshes.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// A window Escape closes (Squiggle's `EscapeClosingWindow`).
final class EscapeClosingWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }
}

/// The app's user-facing version (`CFBundleShortVersionString`, e.g. 1.0.0).
enum AppVersion {
    static var current: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
