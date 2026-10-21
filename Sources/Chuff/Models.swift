import Foundation
import AppKit
import SwiftUI

// MARK: - Raw API shape (https://api.railwaystatus.com/status)
//
// Top level: { "components": [Node], "incidents": [...], "maintenances": [...] }
// A Node is either a "group" (has child `components`, no own status) or a
// standalone "component" (has `status`, no children) — e.g. "Payments & Billing".
// Decoding is deliberately lenient: every field except id/name is optional so a
// new or missing field doesn't break the app.

struct StatusResponse: Decodable {
    let components: [Node]
}

struct Node: Decodable {
    let id: String
    let name: String
    let type: String?
    let status: String?
    let position: Int?
    let components: [Node]?
}

// MARK: - Status level

enum StatusLevel: Int, Comparable {
    case unknown = -1      // no data / couldn't reach the API
    case operational = 0   // green
    case degraded = 1      // amber
    case outage = 2        // red

    static func < (a: StatusLevel, b: StatusLevel) -> Bool { a.rawValue < b.rawValue }

    /// Maps the API's raw status string. Observed values: OPERATIONAL,
    /// PARTIAL_OUTAGE, MAJOR_OUTAGE. Anything unrecognised is treated as
    /// amber rather than green, so an unexpected value never looks healthy.
    init(raw: String?) {
        guard let raw = raw?.uppercased(), !raw.isEmpty else { self = .unknown; return }
        switch raw {
        case "OPERATIONAL":
            self = .operational
        case "MAJOR_OUTAGE", "FULL_OUTAGE":
            self = .outage
        case "PARTIAL_OUTAGE", "DEGRADED_PERFORMANCE", "DEGRADED", "UNDER_MAINTENANCE", "MAINTENANCE":
            self = .degraded
        default:
            self = (raw.contains("MAJOR") || raw.contains("FULL")) ? .outage : .degraded
        }
    }

    var nsColor: NSColor {
        switch self {
        case .operational: return .systemGreen
        case .degraded: return .systemOrange
        case .outage: return .systemRed
        case .unknown: return .systemGray
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    var summary: String {
        switch self {
        case .operational: return "All systems operational"
        case .degraded: return "Degraded / partial outage"
        case .outage: return "Major outage"
        case .unknown: return "Status unavailable"
        }
    }
}

// MARK: - UI models

struct ComponentItem: Identifiable, Equatable {
    let id: String
    let name: String
    let rawStatus: String?
    var level: StatusLevel { StatusLevel(raw: rawStatus) }

    /// "PARTIAL_OUTAGE" -> "Partial outage"
    var statusLabel: String {
        guard let raw = rawStatus, !raw.isEmpty else { return "Unknown" }
        let words = raw.lowercased().replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

struct StatusGroup: Identifiable, Equatable {
    let id: String
    let name: String
    /// Child components. Empty for a standalone component.
    let items: [ComponentItem]
    /// The node's own status (only set for standalone components).
    let ownStatus: String?

    var isStandalone: Bool { items.isEmpty }

    /// Worst of the group's own status and all its children.
    var level: StatusLevel {
        var levels = items.map(\.level)
        if ownStatus != nil { levels.append(StatusLevel(raw: ownStatus)) }
        return levels.max() ?? .unknown
    }

    var affectedCount: Int { items.filter { $0.level > .operational }.count }

    init(node: Node) {
        id = node.id
        name = node.name
        ownStatus = node.status
        items = (node.components ?? [])
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            .map { ComponentItem(id: $0.id, name: $0.name, rawStatus: $0.status) }
    }
}
