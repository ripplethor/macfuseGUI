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
enum AppError: LocalizedError {
    case dependencyMissing(String)
    case validationFailed([String])
    case processFailure(String)
    case keychainError(String)
    case persistenceError(String)
    case remoteBrowserError(String)
    case timeout(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .dependencyMissing(let detail):
            return detail
        case .validationFailed(let errors):
            return errors.joined(separator: "\n")
        case .processFailure(let detail):
            return detail
        case .keychainError(let detail):
            return detail
        case .persistenceError(let detail):
            return detail
        case .remoteBrowserError(let detail):
            return detail
        case .timeout(let detail):
            return detail
        case .unknown(let detail):
            return detail
        }
    }
}
