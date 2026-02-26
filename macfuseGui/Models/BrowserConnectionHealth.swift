// BEGINNER FILE GUIDE
// Layer: Data model layer
// Purpose: This file defines value types and enums shared across services, view models, and views.
// Called by: Constructed and consumed throughout the app where typed state is needed.
// Calls into: Usually has no runtime side effects; mostly pure data definitions.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

typealias RemoteBrowserSessionID = UUID

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum BrowserConnectionState: String, Sendable {
    case connecting
    case healthy
    case degraded
    case reconnecting
    case failed
    case closed
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct BrowserConnectionHealth: Equatable, Sendable {
    let state: BrowserConnectionState
    let retryCount: Int
    let lastError: String?
    let lastSuccessAt: Date?
    let lastLatencyMs: Int?
    let updatedAt: Date

    static var connecting: BrowserConnectionHealth {
        BrowserConnectionHealth(
            state: .connecting,
            retryCount: 0,
            lastError: nil,
            lastSuccessAt: nil,
            lastLatencyMs: nil,
            updatedAt: Date()
        )
    }

    /// Structural Equatable includes timestamps. Use this helper for state-only comparisons.
    func isSemanticallyEquivalent(to other: BrowserConnectionHealth) -> Bool {
        state == other.state
            && retryCount == other.retryCount
            && lastError == other.lastError
            && lastLatencyMs == other.lastLatencyMs
    }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteDirectoryItem: Identifiable, Equatable, Sendable {
    let name: String
    let fullPath: String
    let isDirectory: Bool
    let modifiedAt: Date?
    let sizeBytes: Int64?

    var id: String { fullPath }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteBrowserSnapshot: Equatable, Sendable {
    let path: String
    let entries: [RemoteDirectoryItem]
    let isStale: Bool
    let isConfirmedEmpty: Bool
    let health: BrowserConnectionHealth
    let message: String?
    let generatedAt: Date
    let fromCache: Bool
    let requestID: UInt64
    let latencyMs: Int

    init(
        path: String,
        entries: [RemoteDirectoryItem],
        isStale: Bool,
        isConfirmedEmpty: Bool,
        health: BrowserConnectionHealth,
        message: String?,
        generatedAt: Date,
        fromCache: Bool,
        requestID: UInt64,
        latencyMs: Int
    ) {
        self.path = path
        self.entries = entries
        self.isStale = isStale
        self.isConfirmedEmpty = isConfirmedEmpty && entries.isEmpty
        self.health = health
        self.message = message
        self.generatedAt = generatedAt
        self.fromCache = fromCache
        self.requestID = requestID
        self.latencyMs = latencyMs
    }

    /// Structural Equatable includes timing/request metadata. Use this helper for UI state comparisons.
    func isSemanticallyEquivalent(to other: RemoteBrowserSnapshot) -> Bool {
        path == other.path
            && entries == other.entries
            && isStale == other.isStale
            && isConfirmedEmpty == other.isConfirmedEmpty
            && health.isSemanticallyEquivalent(to: other.health)
            && message == other.message
            && fromCache == other.fromCache
    }
}
