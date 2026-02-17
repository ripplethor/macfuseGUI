// BEGINNER FILE GUIDE
// Layer: Core service layer
// Purpose: This file performs non-UI work such as mount commands, process execution, validation, persistence, or diagnostics.
// Called by: Called by view models to execute user actions and background recovery work.
// Calls into: May call system APIs, external tools, Keychain, filesystem, and helper services.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class RedactionService {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func redact(_ input: String, secrets: [String]) -> String {
        secrets
            .filter { !$0.isEmpty }
            .reduce(input) { partialResult, secret in
                partialResult.replacingOccurrences(of: secret, with: "<redacted>")
            }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func redactedCommand(executable: String, arguments: [String], secrets: [String]) -> String {
        let joined = ([executable] + arguments)
            .map { quoteIfNeeded($0) }
            .joined(separator: " ")
        return redact(joined, secrets: secrets)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func quoteIfNeeded(_ value: String) -> String {
        if value.contains(" ") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
