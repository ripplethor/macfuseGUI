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
enum BrowserConnectionState: String, Codable, Sendable {
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
    var state: BrowserConnectionState
    var retryCount: Int
    var lastError: String?
    var lastSuccessAt: Date?
    var lastLatencyMs: Int?
    var updatedAt: Date

    static let connecting = BrowserConnectionHealth(
        state: .connecting,
        retryCount: 0,
        lastError: nil,
        lastSuccessAt: nil,
        lastLatencyMs: nil,
        updatedAt: Date()
    )
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteDirectoryItem: Identifiable, Equatable, Sendable {
    var name: String
    var fullPath: String
    var isDirectory: Bool
    var modifiedAt: Date?
    var sizeBytes: Int64?

    var id: String { fullPath.lowercased() }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteBrowserSnapshot: Equatable, Sendable {
    var path: String
    var entries: [RemoteDirectoryItem]
    var isStale: Bool
    var isConfirmedEmpty: Bool
    var health: BrowserConnectionHealth
    var message: String?
    var generatedAt: Date
    var fromCache: Bool
    var requestID: UInt64
    var latencyMs: Int
}
