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
struct MountCommand: Sendable {
    let executable: String
    let arguments: [String]
    let environment: [String: String]
    let redactedCommand: String
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class MountCommandBuilder {
    private let redactionService: RedactionService

    /// Beginner note: Initializers create valid state before any other method is used.
    init(redactionService: RedactionService) {
        self.redactionService = redactionService
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func build(
        sshfsPath: String,
        remote: RemoteConfig,
        passwordEnvironment: [String: String] = [:]
    ) -> MountCommand {
        let normalizedRemotePath = normalizedRemoteDirectory(remote.remoteDirectory)

        var options = [
            "reconnect",
            "ServerAliveInterval=15",
            "ServerAliveCountMax=3",
            "defer_permissions",
            "noappledouble",
            "nolocalcaches",
            "auto_cache",
            "StrictHostKeyChecking=accept-new",
            "ConnectTimeout=10",
            "volname=\(volumeName(for: remote, normalizedRemotePath: normalizedRemotePath))"
        ]

        if remote.authMode == .privateKey,
           let key = remote.privateKeyPath,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            options.append("IdentityFile=\(key)")
        }

        var args: [String] = [
            "-p", "\(remote.port)",
            "-o", options.joined(separator: ",")
        ]

        let source = "\(remote.username)@\(remote.host):\(normalizedRemotePath)"
        args.append(source)
        args.append(remote.localMountPoint)

        let redacted = redactionService.redactedCommand(
            executable: sshfsPath,
            arguments: args,
            secrets: askpassSecrets(from: passwordEnvironment)
        )

        return MountCommand(
            executable: sshfsPath,
            arguments: args,
            environment: passwordEnvironment,
            redactedCommand: redacted
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func askpassSecrets(from environment: [String: String]) -> [String] {
        environment.compactMap { key, value in
            if key.hasPrefix("MACFUSEGUI_ASKPASS_PASSWORD") {
                return value
            }
            return nil
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func normalizedRemoteDirectory(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "/"
        }

        if trimmed.hasPrefix("~") {
            return trimmed
        }

        var normalized = trimmed.replacingOccurrences(of: "\\", with: "/")
        if isWindowsDrivePath(normalized), !normalized.hasPrefix("/") {
            normalized = "/\(normalized)"
        }

        return normalized
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func volumeName(for remote: RemoteConfig, normalizedRemotePath: String) -> String {
        var parts: [String] = []

        let display = remote.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !display.isEmpty {
            parts.append(display)
        }

        if let leaf = remotePathLeaf(normalizedRemotePath), !leaf.isEmpty {
            if parts.isEmpty || parts[0].caseInsensitiveCompare(leaf) != .orderedSame {
                parts.append(leaf)
            }
        }

        if parts.isEmpty {
            parts.append(remote.host)
        }

        return sanitizedVolumeName(parts.joined(separator: " - "))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func remotePathLeaf(_ normalizedPath: String) -> String? {
        let trimmed = normalizedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed == "/" {
            return nil
        }

        if trimmed == "~" {
            return "home"
        }

        var path = trimmed
        if path.hasPrefix("~/") {
            path.removeFirst(2)
        }

        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }

        let components = path.split(separator: "/")
        guard let leaf = components.last else {
            return nil
        }
        return String(leaf)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func sanitizedVolumeName(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(
                of: "[^A-Za-z0-9 ._\\-\\(\\)\\[\\]]",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let fallback = cleaned.isEmpty ? "macfuseGui" : cleaned
        return String(fallback.prefix(63))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func isWindowsDrivePath(_ value: String) -> Bool {
        guard value.count >= 2 else {
            return false
        }

        let chars = Array(value)
        guard chars[0].isLetter, chars[1] == ":" else {
            return false
        }

        guard chars.count >= 3 else {
            return true
        }

        return chars[2] == "/" || chars[2] == "\\"
    }
}
