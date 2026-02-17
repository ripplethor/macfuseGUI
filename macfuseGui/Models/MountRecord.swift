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
struct MountRecord: Equatable, Sendable {
    let source: String
    let mountPoint: String
    let filesystemType: String
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteDirectoryEntry: Identifiable, Equatable, Sendable {
    let name: String
    let fullPath: String

    var id: String { fullPath }
}
