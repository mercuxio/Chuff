import SwiftUI
import AppKit

/// Typography and spacing matched to Squiggle's dropdown
/// (~/Projects/Squiggle/Sources/Squiggle/DropdownView.swift, MenuFooterView.swift):
/// - every line of text is the system (menu) font at `NSFont.smallSystemFontSize`
///   (11pt, and it follows the user's text-size setting the same way);
/// - rows are regular weight in the primary label colour;
/// - headings and the status line are the same size, set apart by colour
///   (secondary) and, for headings, semibold weight;
/// - footer icons are 13pt in the secondary colour;
/// - content is inset 14pt from the panel edges.
private enum Typography {
    static let size: CGFloat = NSFont.smallSystemFontSize
    static let row = Font(NSFont.menuFont(ofSize: size) as CTFont)
    static let emphasis = Font.system(size: size, weight: .semibold)
    static let detail = Font.system(size: size)
    static let footerGlyph = Font.system(size: 13, weight: .regular)
    static let inset: CGFloat = 14
}

struct PopoverView: View {
    @ObservedObject var store: StatusStore
    /// Opens the Settings window (owned by the AppDelegate).
    var openSettings: () -> Void = {}
    // Expansion state lives in the store (not @State): on the macOS 27 SDK
    // @State is a macro whose plugin only ships with full Xcode, and this
    // project builds with Command Line Tools alone.
    private var expanded: Set<String> { store.expandedIDs }
    private static let tickWidth: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            statusLine
            Divider()
            FooterBar(refreshing: store.isLoading,
                      showTrackAll: !store.excludedIDs.isEmpty,
                      perform: perform)
                .frame(height: FooterRowView.Metrics.height)
        }
        .font(Typography.row)
        .frame(width: 288)   // 360 reduced by 20%
    }

    // MARK: Header

    private var header: some View {
        // One row: dot · "Railway" · status, with the tracked count on the right.
        // The title and count never shrink; if space runs out, only the status
        // text truncates. Uses the short wording so every status fits at 288pt
        // (the long wording stays in the menubar tooltip).
        HStack(spacing: 8) {
            StatusDot(level: store.overall, size: 10)
            Text("Railway")
                .font(Typography.emphasis)
                .fixedSize()
            Text(store.overallShortDescription)
                .font(Typography.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
            Spacer(minLength: 6)
            Text("\(store.trackedGroups.count)/\(store.groups.count) tracked")
                .font(Typography.detail)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, Typography.inset)
        .padding(.vertical, 10)
    }

    // MARK: Group list

    @ViewBuilder
    private var content: some View {
        if store.groups.isEmpty {
            VStack(spacing: 8) {
                if store.isLoading || store.lastError == nil {
                    ProgressView().controlSize(.small)
                    Text("Loading status…").foregroundStyle(.secondary)
                } else {
                    Image(systemName: "wifi.exclamationmark")
                        .font(Typography.footerGlyph)
                        .foregroundStyle(.secondary)
                    Text("Couldn't load Railway status").foregroundStyle(.secondary)
                }
            }
            .font(Typography.detail)
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.groups) { group in
                        groupRow(group)
                        if expanded.contains(group.id) && !group.isStandalone {
                            ForEach(group.items) { item in itemRow(item) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 480)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func groupRow(_ group: StatusGroup) -> some View {
        let tracked = store.isTracked(group)
        return HStack(spacing: 8) {
            Button {
                guard !group.isStandalone else { return }
                store.toggleExpanded(group)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded.contains(group.id) ? 90 : 0))
                        .opacity(group.isStandalone ? 0 : 1)
                        .frame(width: 8)
                    StatusDot(level: group.level, size: 8)
                    Text(group.name)
                        .font(Typography.row)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    if let text = groupStatusText(group) {
                        Text(text)
                            .font(Typography.detail)
                            .foregroundStyle(group.level.color)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Tick (right-aligned) = include this group in the menubar colour.
            // Click to toggle. Untracked groups keep a faint tick so the click
            // target stays visible.
            Button {
                store.setTracked(group, !tracked)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: Typography.size, weight: .bold))
                    // Dark grey when tracked (primary at 70%: ~#4D4D4D in light
                    // mode, a soft light grey in dark mode so it stays visible).
                    .foregroundStyle(tracked ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.25))
                    .frame(width: Self.tickWidth, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tracked ? "Tracked — click to exclude from the menubar status"
                          : "Not tracked — click to include in the menubar status")
            .accessibilityLabel(tracked ? "Tracked" : "Not tracked")
        }
        .opacity(tracked ? 1 : 0.5)
        .padding(.horizontal, Typography.inset)
        .padding(.vertical, 5)
    }

    /// Groups rely on their dot alone. The one exception is a standalone
    /// component (e.g. Payments & Billing): it has no items to expand, so when
    /// it's not operational its status text is the only place the detail shows.
    private func groupStatusText(_ group: StatusGroup) -> String? {
        guard group.isStandalone, group.level > .operational else { return nil }
        return ComponentItem(id: group.id, name: group.name, rawStatus: group.ownStatus).statusLabel
    }

    private func itemRow(_ item: ComponentItem) -> some View {
        HStack(spacing: 8) {
            StatusDot(level: item.level, size: 6)
            Text(item.name)
                .font(Typography.row)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            // Green dot already says "operational"; only spell out problems.
            if item.level > .operational {
                Text(item.statusLabel)
                    .font(Typography.detail)
                    .foregroundStyle(item.level.color)
            }
        }
        // Indent so the item's dot lines up under the group name:
        // inset + chevron(8) + gap(8) + dot(8) + gap(8).
        .padding(.leading, Typography.inset + 32)
        // Keep item status text in the same column as group status text,
        // i.e. to the left of the tick column: inset + gap(8) + tick.
        .padding(.trailing, Typography.inset + 8 + Self.tickWidth)
        .padding(.vertical, 3)
    }

    // MARK: Status line + footer (Squiggle's layout)

    /// Squiggle's status line: one line of 11pt secondary text above the
    /// separator, inset 14, 4pt above and below, wrapping rather than
    /// truncating so an error message is readable to the end.
    @ViewBuilder
    private var statusLine: some View {
        if let text = statusText {
            Text(text)
                .font(Typography.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Typography.inset)
                .padding(.vertical, 4)
        }
    }

    private var statusText: String? {
        let updated = store.lastUpdated.map {
            "Updated \($0.formatted(date: .omitted, time: .shortened))"
        }
        if let error = store.lastError {
            return [ "Refresh failed: \(error)", updated.map { "Last \($0.lowercased())" } ]
                .compactMap { $0 }.joined(separator: " · ")
        }
        return updated
    }

    private func perform(_ command: FooterCommand) {
        switch command {
        case .settings: openSettings()
        case .refresh: Task { await store.refresh() }
        case .openStatusPage: NSWorkspace.shared.open(StatusStore.statusPage)
        case .buyCoffee: NSWorkspace.shared.open(FooterCommand.coffeeURL)
        case .trackAll: store.trackAll()
        case .quit: NSApp.terminate(nil)
        }
    }
}

struct StatusDot: View {
    let level: StatusLevel
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(level.color)
            .frame(width: size, height: size)
    }
}
