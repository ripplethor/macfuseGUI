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
struct RedactionService {
    private let replacementToken = "<redacted>"

    /// Beginner note: This method is one step in the feature workflow for this file.
    func redact(_ input: String, secrets: [String]) -> String {
        // Redaction is literal and case-sensitive by design.
        // Callers should provide any additional transformed forms of the secret if needed.
        let orderedSecrets = normalizedSecrets(from: secrets)
        guard !orderedSecrets.isEmpty else {
            return input
        }

        let sentinel = uniqueSentinel(for: input, secrets: orderedSecrets)
        let sentinelReplaced = orderedSecrets.reduce(input) { partialResult, secret in
            partialResult.replacingOccurrences(of: secret, with: sentinel)
        }

        return sentinelReplaced.replacingOccurrences(of: sentinel, with: replacementToken)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func redactedCommand(executable: String, arguments: [String], secrets: [String]) -> String {
        let redactedParts = ([executable] + arguments)
            .map { redact($0, secrets: secrets) }
            // Display/log formatting only. This is not guaranteed to be shell-safe for copy/paste execution.
            .map { quoteForDisplayIfNeeded($0) }
            .joined(separator: " ")
        return redactedParts
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func quoteForDisplayIfNeeded(_ value: String) -> String {
        if value.contains(" ") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func normalizedSecrets(from secrets: [String]) -> [String] {
        let sorted = secrets
            .filter { !$0.isEmpty }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count > rhs.count
            }

        var seen: Set<String> = []
        return sorted.filter { seen.insert($0).inserted }
    }

    /// Beginner note: Use a unique sentinel so replacement output is never re-redacted by later passes.
    private func uniqueSentinel(for input: String, secrets: [String]) -> String {
        var candidate = "\u{1F}MACFUSEGUI_REDACTION_SENTINEL\u{1F}"
        while input.contains(candidate) || secrets.contains(where: { $0.contains(candidate) }) {
            candidate = "\u{1F}MACFUSEGUI_REDACTION_SENTINEL_\(UUID().uuidString)\u{1F}"
        }
        return candidate
    }
}
