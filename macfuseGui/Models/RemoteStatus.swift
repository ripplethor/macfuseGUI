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
enum RemoteConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteStatus: Equatable, Sendable {
    var state: RemoteConnectionState
    var mountedPath: String?
    var lastError: String?
    var updatedAt: Date

    /// Beginner note: Initializers create valid state before any other method is used.
    init(
        state: RemoteConnectionState = .disconnected,
        mountedPath: String? = nil,
        lastError: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.state = state
        self.mountedPath = mountedPath
        self.lastError = lastError
        self.updatedAt = updatedAt
    }

    static let disconnected = RemoteStatus(state: .disconnected)
}
