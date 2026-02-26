// BEGINNER FILE GUIDE
// Layer: Data model layer
// Purpose: This file defines value types and enums shared across services, view models, and views.
// Called by: Constructed and consumed throughout the app where typed state is needed.
// Calls into: Usually has no runtime side effects; mostly pure data definitions.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum RemoteConnectionState: String, Codable, Hashable, CaseIterable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error
}

/// Beginner note: This enum is a UI badge-oriented state model.
/// It includes synthetic states (for example reconnecting) that are derived by view models.
enum RemoteStatusBadgeState: String, Sendable {
    case disconnected
    case connecting
    case reconnecting
    case connected
    case disconnecting
    case error

    init(connectionState: RemoteConnectionState) {
        switch connectionState {
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .disconnecting:
            self = .disconnecting
        case .error:
            self = .error
        }
    }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteStatus: Codable, Equatable, Hashable, Sendable {
    var state: RemoteConnectionState = .disconnected
    var mountedPath: String? = nil
    var lastError: String? = nil
    var updatedAt: Date = Date()

    /// Beginner note: This method is one step in the feature workflow for this file.
    var isActive: Bool {
        state == .connected || state == .connecting
    }

    /// Beginner note: UI connect action is available when currently disconnected,
    /// transitioning to disconnected, or in an error state.
    var canConnect: Bool {
        state == .disconnected || state == .error || state == .disconnecting
    }

    /// Beginner note: UI disconnect action is available while connected or in-flight connect.
    var canDisconnect: Bool {
        state == .connected || state == .connecting
    }

    static let initial = RemoteStatus(state: .disconnected)
}

extension String {
    /// Collapse whitespace/newlines to single spaces and truncate with an ellipsis.
    func collapsedAndTruncatedForDisplay(limit: Int = 180) -> String {
        let collapsed = replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if collapsed.count <= limit {
            return collapsed
        }
        return "\(collapsed.prefix(limit))…"
    }
}
