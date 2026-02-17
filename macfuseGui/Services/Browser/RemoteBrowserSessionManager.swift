// BEGINNER FILE GUIDE
// Layer: Browser service layer
// Purpose: This file implements remote directory browsing sessions, transport, parsing, or path normalization.
// Called by: Called from RemoteDirectoryBrowserService and browser-facing view models.
// Calls into: Calls into libssh2 bridge, diagnostics, and browser state models.
// Concurrency: Uses a Swift actor for data-race safety; actor methods execute in an isolated concurrency domain.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
actor RemoteBrowserSessionManager {
    private let transport: BrowserTransport
    private let diagnostics: DiagnosticsService
    private var sessions: [RemoteBrowserSessionID: LibSSH2SessionActor] = [:]

    /// Beginner note: Initializers create valid state before any other method is used.
    init(transport: BrowserTransport, diagnostics: DiagnosticsService) {
        self.transport = transport
        self.diagnostics = diagnostics
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func openSession(remote: RemoteConfig, password: String?) -> RemoteBrowserSessionID {
        let sessionID = UUID()
        let session = LibSSH2SessionActor(
            id: sessionID,
            remote: remote,
            password: password,
            transport: transport,
            diagnostics: diagnostics
        )
        sessions[sessionID] = session
        diagnostics.append(
            level: .info,
            category: "remote-browser",
            message: "Opened browser session \(sessionID.uuidString) for \(remote.displayName)"
        )
        return sessionID
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func closeSession(_ sessionID: RemoteBrowserSessionID) async {
        guard let session = sessions.removeValue(forKey: sessionID) else {
            return
        }
        await session.close()
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func listDirectories(sessionID: RemoteBrowserSessionID, path: String, requestID: UInt64) async -> RemoteBrowserSnapshot {
        guard let session = sessions[sessionID] else {
            return missingSessionSnapshot(path: path, requestID: requestID)
        }
        return await session.list(path: path, requestID: requestID)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func goUp(sessionID: RemoteBrowserSessionID, currentPath: String, requestID: UInt64) async -> RemoteBrowserSnapshot {
        guard let session = sessions[sessionID] else {
            return missingSessionSnapshot(path: currentPath, requestID: requestID)
        }
        return await session.goUp(currentPath: currentPath, requestID: requestID)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func retryCurrentPath(sessionID: RemoteBrowserSessionID, requestID: UInt64) async -> RemoteBrowserSnapshot {
        guard let session = sessions[sessionID] else {
            return missingSessionSnapshot(path: "/", requestID: requestID)
        }
        return await session.retryCurrentPath(requestID: requestID)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func health(sessionID: RemoteBrowserSessionID) async -> BrowserConnectionHealth {
        guard let session = sessions[sessionID] else {
            return BrowserConnectionHealth(
                state: .closed,
                retryCount: 0,
                lastError: "Session not found",
                lastSuccessAt: nil,
                lastLatencyMs: nil,
                updatedAt: Date()
            )
        }
        return await session.currentHealth()
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func sessionsSummary() async -> String {
        if sessions.isEmpty {
            return "- none"
        }
        var lines: [String] = []
        for (id, session) in sessions {
            let line = await session.summaryLine()
            lines.append(line.isEmpty ? "- session=\(id.uuidString)" : line)
        }
        return lines.sorted().joined(separator: "\n")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func missingSessionSnapshot(path: String, requestID: UInt64) -> RemoteBrowserSnapshot {
        let normalized = BrowserPathNormalizer.normalize(path: path)
        return RemoteBrowserSnapshot(
            path: normalized,
            entries: [],
            isStale: true,
            isConfirmedEmpty: false,
            health: BrowserConnectionHealth(
                state: .closed,
                retryCount: 0,
                lastError: "Browser session closed",
                lastSuccessAt: nil,
                lastLatencyMs: nil,
                updatedAt: Date()
            ),
            message: "Browser session closed. Re-open the browser.",
            generatedAt: Date(),
            fromCache: false,
            requestID: requestID,
            latencyMs: 0
        )
    }
}
