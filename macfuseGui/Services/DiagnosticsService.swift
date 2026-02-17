// BEGINNER FILE GUIDE
// Layer: Core service layer
// Purpose: This file performs non-UI work such as mount commands, process execution, validation, persistence, or diagnostics.
// Called by: Called by view models to execute user actions and background recovery work.
// Calls into: May call system APIs, external tools, Keychain, filesystem, and helper services.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation
import os

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum DiagnosticLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct DiagnosticEntry: Sendable {
    let timestamp: Date
    let level: DiagnosticLevel
    let category: String
    let message: String
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class DiagnosticsService {
    private let logger = Logger(subsystem: "com.visualweb.macfusegui", category: "app")
    private let queue = DispatchQueue(label: "com.visualweb.macfusegui.diagnostics")
    private let maxEntries: Int
    private var entries: [DiagnosticEntry] = []

    /// Beginner note: Initializers create valid state before any other method is used.
    init(maxEntries: Int = 400) {
        self.maxEntries = maxEntries
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func append(level: DiagnosticLevel, category: String, message: String) {
        let sanitized = message.replacingOccurrences(of: "\n", with: " ")
        let entry = DiagnosticEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: sanitized
        )

        queue.sync {
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
        }

        switch level {
        case .debug:
            logger.debug("[\(category, privacy: .public)] \(sanitized, privacy: .public)")
        case .info:
            logger.info("[\(category, privacy: .public)] \(sanitized, privacy: .public)")
        case .warning:
            logger.warning("[\(category, privacy: .public)] \(sanitized, privacy: .public)")
        case .error:
            logger.error("[\(category, privacy: .public)] \(sanitized, privacy: .public)")
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func snapshot(
        remotes: [RemoteConfig],
        statuses: [UUID: RemoteStatus],
        dependency: DependencyStatus?,
        browserSessions: String? = nil,
        operations: String? = nil
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = []
        lines.append("macfuseGui diagnostics")
        lines.append("Generated: \(formatter.string(from: Date()))")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")

        if let dependency {
            lines.append("Dependencies ready: \(dependency.isReady)")
            lines.append("sshfs path: \(dependency.sshfsPath ?? "not found")")
            if !dependency.issues.isEmpty {
                lines.append("Dependency issues:")
                dependency.issues.forEach { lines.append("- \($0)") }
            }
        }

        lines.append("Remotes:")
        if remotes.isEmpty {
            lines.append("- none")
        } else {
            for remote in remotes {
                let status = statuses[remote.id] ?? .disconnected
                let errorText = status.lastError ?? ""
                lines.append("- \(remote.displayName) [\(remote.host):\(remote.port)] status=\(status.state.rawValue) mount=\(status.mountedPath ?? "-") error=\(errorText)")
            }
        }

        lines.append("Recent logs:")
        let captured = queue.sync { entries }
        if captured.isEmpty {
            lines.append("- none")
        } else {
            for entry in captured.suffix(200) {
                lines.append("- \(formatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)")
            }
        }

        lines.append("Operations:")
        if let operations, !operations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(contentsOf: operations.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        } else {
            lines.append("- none")
        }

        lines.append("Browser Sessions:")
        if let browserSessions, !browserSessions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(contentsOf: browserSessions.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        } else {
            lines.append("- none")
        }

        return lines.joined(separator: "\n")
    }
}
