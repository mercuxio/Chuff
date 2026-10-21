import AppKit
import SwiftUI

/// The icon row at the bottom of the popover — a port of Squiggle's
/// `MenuFooterView` (which is Pitch's, which took its metrics from InOut), so
/// the two menubar apps' footers look like siblings:
/// - 31pt tall; 13pt glyphs; each button is the glyph plus 4pt hit slop a side;
/// - icons on the left 2pt apart, the visible glyph 14pt from the edge;
/// - quit (Lucide log-out) alone on the right, 14pt from that edge;
/// - icons rest in `secondaryLabelColor` and brighten to `labelColor` under
///   the pointer;
/// - refresh spins (clockwise, 0.9s a turn) while a fetch is running, or just
///   brightens when Reduce Motion is on.
enum FooterCommand: CaseIterable {
    case settings, refresh, openStatusPage, buyCoffee, trackAll, quit

    /// Same address as Squiggle's coffee button (Squiggle/ErrorText.swift).
    static let coffeeURL = URL(string: "https://buymeacoffee.com/benjamintan")!

    var title: String {
        switch self {
        case .settings: return "Settings…"
        case .refresh: return "Refresh now"
        case .openStatusPage: return "Open status.railway.com"
        case .buyCoffee: return "Buy me a coffee"
        case .trackAll: return "Track all groups"
        case .quit: return "Quit Chuff"
        }
    }

    /// Settings is an SF Symbol (`gearshape`); the rest are Lucide — the same
    /// mix as Squiggle's and Pitch's footers.
    func image(size: CGFloat) -> NSImage? {
        switch self {
        case .settings:
            return NSImage(systemSymbolName: "gearshape", accessibilityDescription: title)?
                .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
        case .refresh: return LucideIcon.refreshCw.image(size: size)
        case .openStatusPage: return LucideIcon.externalLink.image(size: size)
        case .buyCoffee: return LucideIcon.coffee.image(size: size)
        case .trackAll: return LucideIcon.checkCheck.image(size: size)
        case .quit: return LucideIcon.logOut.image(size: size)
        }
    }
}

/// SwiftUI wrapper. Rebuilds the row when what it shows changes, the same way
/// Squiggle rebuilds its footer rather than mutating buttons in place.
struct FooterBar: NSViewRepresentable {
    var refreshing: Bool
    var showTrackAll: Bool
    var perform: (FooterCommand) -> Void

    func makeNSView(context: Context) -> FooterRowView {
        FooterRowView()
    }

    func updateNSView(_ view: FooterRowView, context: Context) {
        view.perform = perform
        view.configure(refreshing: refreshing, showTrackAll: showTrackAll)
    }
}

final class FooterRowView: NSView {
    enum Metrics {
        static let height: CGFloat = 31
        static let visibleInset: CGFloat = 14
        static let spacing: CGFloat = 2
        static let glyph: CGFloat = 13
        static let hitSlop: CGFloat = 4
    }

    var perform: ((FooterCommand) -> Void)?
    private var current: (refreshing: Bool, showTrackAll: Bool)?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Metrics.height)
    }

    func configure(refreshing: Bool, showTrackAll: Bool) {
        if let current, current == (refreshing, showTrackAll) { return }
        current = (refreshing, showTrackAll)

        subviews.forEach { $0.removeFromSuperview() }

        // The always-present icons first, so the conditional "track all" one
        // appearing at the end never shifts the others under the pointer.
        // Gear first, as in Squiggle's footer.
        var leadingCommands: [FooterCommand] = [.settings, .refresh, .openStatusPage, .buyCoffee]
        if showTrackAll { leadingCommands.append(.trackAll) }

        let leading = NSStackView(views: leadingCommands.map {
            button(for: $0, refreshing: $0 == .refresh && refreshing)
        })
        leading.orientation = .horizontal
        leading.spacing = Metrics.spacing

        let quit = button(for: .quit, refreshing: false)

        for view in [leading, quit] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            leading.leadingAnchor.constraint(equalTo: leadingAnchor,
                                             constant: Metrics.visibleInset - Metrics.hitSlop),
            leading.centerYAnchor.constraint(equalTo: centerYAnchor),
            quit.trailingAnchor.constraint(equalTo: trailingAnchor,
                                           constant: -(Metrics.visibleInset - Metrics.hitSlop)),
            quit.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func button(for command: FooterCommand, refreshing: Bool) -> NSButton {
        let spin = refreshing && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let button: FooterButton = spin ? SpinningFooterButton(frame: .zero) : FooterButton()
        // The spinning button strokes its own glyph; an image too would draw two.
        button.image = spin ? nil : command.image(size: Metrics.glyph)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.command = command
        button.target = self
        button.action = #selector(clicked(_:))
        button.toolTip = command.title
        button.setAccessibilityLabel(command.title)
        // The live icon (refreshing) reads in full label colour, like hover.
        button.contentTintColor = refreshing ? .labelColor : .secondaryLabelColor
        button.restingTint = button.contentTintColor ?? .secondaryLabelColor

        let side = Metrics.glyph + Metrics.hitSlop * 2
        button.widthAnchor.constraint(equalToConstant: side).isActive = true
        button.heightAnchor.constraint(equalToConstant: side).isActive = true
        return button
    }

    @objc private func clicked(_ sender: FooterButton) {
        guard let command = sender.command else { return }
        perform?(command)
    }
}

/// A borderless icon button that lights up under the pointer (Squiggle's
/// `FooterButton`).
class FooterButton: NSButton {
    var command: FooterCommand?
    var restingTint: NSColor = .secondaryLabelColor
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { contentTintColor = .labelColor }
    override func mouseExited(with event: NSEvent) { contentTintColor = restingTint }
}

/// The refresh icon while a fetch is in flight (Squiggle's
/// `SpinningFooterButton`): the same refresh-cw glyph, stroked into its own
/// sublayer so it turns about its centre, clockwise like its arrowheads.
final class SpinningFooterButton: FooterButton {
    static let turnSeconds: Double = 0.9
    let spinner = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        let side = FooterRowView.Metrics.glyph
        spinner.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        spinner.path = LucideIcon.refreshCw.cgPath(size: side)
        spinner.lineWidth = LucideIcon.strokeWidth(size: side)
        spinner.lineCap = .round
        spinner.lineJoin = .round
        spinner.fillColor = nil
        spinner.strokeColor = NSColor.labelColor.cgColor
        spinner.actions = ["position": NSNull()]

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = Self.turnSeconds
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        spin.repeatCount = .infinity
        spinner.add(spin, forKey: "chuff.refresh.spin")

        layer?.addSublayer(spinner)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("built in code") }

    override func layout() {
        super.layout()
        spinner.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            spinner.strokeColor = NSColor.labelColor.cgColor
        }
    }
}
