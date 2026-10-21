import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StatusStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start Sparkle now so scheduled update checks run from launch.
        UpdateChecker.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        // The popover's SwiftUI content is built when it opens and released
        // when it closes (see popoverDidClose), so a closed popover costs no
        // memory and isn't re-diffed on every poll.
        popover.behavior = .transient   // closes when you click elsewhere
        popover.animates = true
        popover.delegate = self

        // objectWillChange fires *before* the value changes, so hop to the next
        // run-loop turn before reading the new overall status.
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        updateIcon()
        store.start()
    }

    /// What the menubar currently shows; the icon is only redrawn when this
    /// changes, not on every poll.
    private struct IconState: Equatable {
        let level: StatusLevel
        let monochrome: Bool
        let description: String
    }
    private var shownIcon: IconState?

    /// Menubar icon sizes, in points. Both sit in an 18pt canvas inside the
    /// status item's square slot.
    static let dotDiameter: CGFloat = 13   // coloured dot (was 11)
    static let symbolSize: CGFloat = 17    // monochrome Lucide symbol (was 15)

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let state = IconState(level: store.overall,
                              monochrome: store.monochromeIcons,
                              description: store.overallDescription)
        guard state != shownIcon else { return }
        shownIcon = state
        button.image = state.monochrome
            ? Self.symbolImage(for: state.level)
            : Self.circleImage(color: state.level.nsColor)
        button.toolTip = "Railway: \(state.description)"
        button.setAccessibilityLabel("Railway status: \(state.description)")
    }

    /// Settings → Monochrome icons: a Lucide symbol per status, drawn as a
    /// template image so macOS tints it like any other menubar icon (black in a
    /// light menubar, white in a dark one).
    private static func symbolImage(for level: StatusLevel) -> NSImage {
        let icon: LucideIcon
        switch level {
        case .operational: icon = .circleCheck
        case .degraded: icon = .circleAlert
        case .outage: icon = .circleX
        case .unknown: icon = .circleMinus
        }
        // 17pt (was 15): the ring is 20/24 of that ≈ 14pt across, which
        // balances visually with the 13pt filled dot. Template already.
        return icon.image(size: Self.symbolSize)
    }

    /// The coloured dot (default): a non-template image so macOS keeps the
    /// colour instead of tinting it black/white.
    private static func circleImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let diameter = Self.dotDiameter
            let circle = NSRect(x: (rect.width - diameter) / 2,
                                y: (rect.height - diameter) / 2,
                                width: diameter, height: diameter)
            color.setFill()
            NSBezierPath(ovalIn: circle).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func openSettings() {
        popover.performClose(nil)
        let controller = settingsWindow ?? SettingsWindowController(store: store)
        settingsWindow = controller
        controller.present()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            Task { await store.refresh() }   // fresh data every time it opens
            let host = NSHostingController(rootView: PopoverView(
                store: store,
                openSettings: { [weak self] in self?.openSettings() }))
            host.sizingOptions = [.preferredContentSize]
            popover.contentViewController = host
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

extension AppDelegate: NSPopoverDelegate {
    /// Release the SwiftUI view tree while the popover is closed.
    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}
