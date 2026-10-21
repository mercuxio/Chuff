import Foundation
import Sparkle

/// The seam between Settings and Sparkle — ported from Squiggle's
/// `Updater.swift`: a struct of closures with one real implementation, so this
/// is the only file that imports Sparkle.
///
/// Updates come from the appcast named by `SUFeedURL` in Resources/Info.plist
/// and are verified against `SUPublicEDKey` there. Sparkle does the download,
/// the signature check and the replacement.
struct UpdateChecker {
    /// False when there is no .app bundle (e.g. `swift run`) or no feed URL —
    /// Sparkle can't work there, so Settings hides the update controls.
    var isAvailable: Bool
    var automaticallyChecks: () -> Bool
    var setAutomaticallyChecks: (Bool) -> Void
    /// Opens Sparkle's own check-for-updates UI.
    var checkNow: () -> Void

    @MainActor
    static let unavailable = UpdateChecker(
        isAvailable: false,
        automaticallyChecks: { false },
        setAutomaticallyChecks: { _ in },
        checkNow: {})

    @MainActor
    static var sparkle: UpdateChecker {
        guard let updater = SparkleUpdater.shared else { return .unavailable }
        return UpdateChecker(
            isAvailable: true,
            automaticallyChecks: { updater.automaticallyChecks },
            setAutomaticallyChecks: { updater.automaticallyChecks = $0 },
            checkNow: { updater.checkNow() })
    }

    /// Starts the updater. Called once at launch so scheduled background
    /// checks run from the start, not only after Settings is first opened.
    @MainActor
    static func start() { _ = SparkleUpdater.shared }

    static func canUpdate(_ bundle: Bundle) -> Bool {
        bundle.bundleURL.pathExtension == "app"
            && bundle.infoDictionary?["SUFeedURL"] as? String != nil
    }
}

/// Holds the one `SPUStandardUpdaterController` for the life of the process.
@MainActor
private final class SparkleUpdater {
    static let shared: SparkleUpdater? =
        UpdateChecker.canUpdate(.main) ? SparkleUpdater() : nil

    /// `startingUpdater: true` schedules the background check that
    /// `SUEnableAutomaticChecks` permits. Sparkle's standard UI is the whole
    /// interface, same as Squiggle.
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkNow() { controller.checkForUpdates(nil) }
}
