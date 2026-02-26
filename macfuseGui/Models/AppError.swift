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
enum AppError: LocalizedError, Equatable, Sendable {
    enum Kind: String, Sendable {
        case dependencyMissing
        case validationFailed
        case processFailure
        case keychainError
        case persistenceError
        case remoteBrowserError
        case timeout
        case unknown
    }

    case dependencyMissing(String)
    case validationFailed([String])
    case processFailure(String)
    case keychainError(String)
    case persistenceError(String)
    case remoteBrowserError(String)
    case timeout(String)
    // Prefer using a specific AppError case when possible.
    case unknown(String)

    var kind: Kind {
        switch self {
        case .dependencyMissing:
            return .dependencyMissing
        case .validationFailed:
            return .validationFailed
        case .processFailure:
            return .processFailure
        case .keychainError:
            return .keychainError
        case .persistenceError:
            return .persistenceError
        case .remoteBrowserError:
            return .remoteBrowserError
        case .timeout:
            return .timeout
        case .unknown:
            return .unknown
        }
    }

    var validationErrors: [String]? {
        guard case .validationFailed(let errors) = self else {
            return nil
        }
        return errors
    }

    var userMessage: String {
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

    var errorDescription: String? {
        userMessage
    }

    var failureReason: String? {
        switch self {
        case .dependencyMissing:
            return "A required system dependency is unavailable."
        case .validationFailed:
            return "Provided input did not pass validation."
        case .processFailure:
            return "An external command failed."
        case .keychainError:
            return "A secure credential operation failed."
        case .persistenceError:
            return "Configuration data could not be loaded or saved."
        case .remoteBrowserError:
            return "Remote directory browsing failed."
        case .timeout:
            return "The operation exceeded its time limit."
        case .unknown:
            return "An internal error occurred."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .dependencyMissing:
            return "Install missing dependencies and try again."
        case .validationFailed:
            return "Correct the highlighted values and try again."
        case .processFailure:
            return "Review diagnostics for command details, then retry."
        case .keychainError:
            return "Unlock Keychain or grant required permissions, then retry."
        case .persistenceError:
            return "Check disk permissions and available space, then retry."
        case .remoteBrowserError:
            return "Verify connection settings and credentials, then retry."
        case .timeout:
            return "Check network/system load and retry."
        case .unknown:
            return "Retry the operation. If it persists, copy diagnostics and contact support."
        }
    }
}
