import Foundation
import AppKit

@MainActor
final class StatusStore: ObservableObject {
    static let endpoint = URL(string: "https://api.railwaystatus.com/status")!
    static let statusPage = URL(string: "https://status.railway.com")!

    /// Settings → Refresh every: the slider's stops, in minutes.
    static let refreshChoices = [1, 3, 5, 10]
    static let defaultRefreshMinutes = 1
    private static let refreshKey = "refreshIntervalMinutes"

    @Published var refreshMinutes: Int = {
        let stored = UserDefaults.standard.integer(forKey: StatusStore.refreshKey)
        return StatusStore.refreshChoices.contains(stored) ? stored : StatusStore.defaultRefreshMinutes
    }() {
        didSet {
            guard refreshMinutes != oldValue else { return }
            UserDefaults.standard.set(refreshMinutes, forKey: Self.refreshKey)
            // Apply straight away (unless polling is paused for sleep).
            if timer != nil { scheduleTimer() }
        }
    }

    /// How often to poll the API.
    var pollInterval: TimeInterval { TimeInterval(refreshMinutes * 60) }

    /// If the last successful refresh is older than this, the icon turns grey
    /// instead of showing a possibly outdated colour. Scales with the interval
    /// (2½ polls, never under 5 min) so a slow interval doesn't grey out
    /// between ordinary refreshes — one missed poll is tolerated, two aren't.
    var staleAfter: TimeInterval { max(5 * 60, pollInterval * 2.5) }

    @Published private(set) var groups: [StatusGroup] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false

    /// Groups the user has UN-ticked. Stored as exclusions so every group is
    /// tracked by default, including any new group Railway adds later.
    @Published var excludedIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(excludedIDs), forKey: Self.excludedKey) }
    }
    private static let excludedKey = "excludedGroupIDs"

    /// Settings → Monochrome icons. Off by default (coloured dot).
    @Published var monochromeIcons: Bool = UserDefaults.standard.bool(forKey: StatusStore.monochromeKey) {
        didSet { UserDefaults.standard.set(monochromeIcons, forKey: Self.monochromeKey) }
    }
    private static let monochromeKey = "monochromeIcons"

    private var timer: Timer?

    init() {
        excludedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.excludedKey) ?? [])
    }

    // MARK: Derived state

    func isTracked(_ group: StatusGroup) -> Bool { !excludedIDs.contains(group.id) }

    func setTracked(_ group: StatusGroup, _ tracked: Bool) {
        if tracked { excludedIDs.remove(group.id) } else { excludedIDs.insert(group.id) }
    }

    func trackAll() { excludedIDs.removeAll() }

    /// Which groups are expanded in the popover (UI state, not persisted).
    @Published private(set) var expandedIDs: Set<String> = []

    func toggleExpanded(_ group: StatusGroup) {
        if expandedIDs.contains(group.id) { expandedIDs.remove(group.id) } else { expandedIDs.insert(group.id) }
    }

    var trackedGroups: [StatusGroup] { groups.filter(isTracked) }

    var isStale: Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > staleAfter
    }

    /// The menubar colour: worst status across tracked groups.
    var overall: StatusLevel {
        if isStale { return .unknown }
        let tracked = trackedGroups
        if tracked.isEmpty { return .unknown }
        return tracked.map(\.level).max() ?? .unknown
    }

    /// Short form for the popover header, which reads "Railway  <this>" on one
    /// row in a 288pt popover. The long form below is kept for the tooltip.
    var overallShortDescription: String {
        if lastUpdated == nil { return lastError == nil ? "Checking…" : "Can't connect" }
        if isStale { return "Out of date" }
        if trackedGroups.isEmpty { return "Nothing tracked" }
        switch overall {
        case .operational: return "Operational"
        case .degraded: return "Partial outage"
        case .outage: return "Major outage"
        case .unknown: return "Unavailable"
        }
    }

    var overallDescription: String {
        if lastUpdated == nil { return lastError == nil ? "Checking…" : "Can't reach Railway status" }
        if isStale { return "Status out of date" }
        if trackedGroups.isEmpty { return "No groups tracked" }
        return overall.summary
    }

    // MARK: Polling

    /// Ephemeral session with no URL cache: every poll wants fresh data, so
    /// the shared session's on-disk response cache (Cache.db) was pure write
    /// traffic. gzip is still negotiated automatically (~3 KB per poll).
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
    }()

    /// Polling pauses while the display sleeps (nobody can see the menubar)
    /// and resumes with an immediate refresh when it wakes.
    private var paused = false

    func start() {
        Task { await refresh() }
        scheduleTimer()

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.pause() }
            }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.resume() }
            }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        // 10% tolerance lets macOS coalesce this wake-up with other timers.
        timer.tolerance = pollInterval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func pause() {
        guard !paused else { return }
        paused = true
        timer?.invalidate()
        timer = nil
    }

    private func resume() {
        guard paused else { return }
        paused = false
        Task { await refresh() }
        scheduleTimer()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }
            let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
            let newGroups = decoded.components.map(StatusGroup.init(node:))
            // Only publish a new list when something actually changed.
            if newGroups != groups { groups = newGroups }
            lastUpdated = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            // Re-publish so the icon can turn grey once the data goes stale.
            objectWillChange.send()
        }
    }
}
