// BEGINNER FILE GUIDE
// Layer: Core service layer
// Purpose: This file performs non-UI work such as mount commands, process execution, validation, persistence, or diagnostics.
// Called by: Called by view models to execute user actions and background recovery work.
// Calls into: May call system APIs, external tools, Keychain, filesystem, and helper services.
// Concurrency: Contains async functions; these can suspend and resume without blocking the calling thread.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class RemoteDirectoryBrowserService {
    private let manager: RemoteBrowserSessionManager
    private let diagnostics: DiagnosticsService

    /// Beginner note: Initializers create valid state before any other method is used.
    init(manager: RemoteBrowserSessionManager, diagnostics: DiagnosticsService) {
        self.manager = manager
        self.diagnostics = diagnostics
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func openSession(remote: RemoteConfig, password: String?) async -> RemoteBrowserSessionID {
        let sessionID = await manager.openSession(remote: remote, password: password)
        return sessionID
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func closeSession(_ sessionID: RemoteBrowserSessionID) async {
        await manager.closeSession(sessionID)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func listDirectories(sessionID: RemoteBrowserSessionID, path: String, requestID: UInt64) async -> RemoteBrowserSnapshot {
        let normalized = BrowserPathNormalizer.normalize(path: path)
        let snapshot = await manager.listDirectories(sessionID: sessionID, path: normalized, requestID: requestID)
        diagnostics.append(
            level: .debug,
            category: "remote-browser",
            message: "Snapshot requestID=\(requestID) session=\(sessionID.uuidString) path=\(snapshot.path) state=\(snapshot.health.state.rawValue) stale=\(snapshot.isStale) confirmedEmpty=\(snapshot.isConfirmedEmpty) entries=\(snapshot.entries.count) latencyMs=\(snapshot.latencyMs) fromCache=\(snapshot.fromCache)"
        )
        return snapshot
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func goUp(sessionID: RemoteBrowserSessionID, currentPath: String, requestID: UInt64) async -> RemoteBrowserSnapshot {
        await manager.goUp(sessionID: sessionID, currentPath: currentPath, requestID: requestID)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func retryCurrentPath(
        sessionID: RemoteBrowserSessionID,
        lastKnownPath: String,
        requestID: UInt64
    ) async -> RemoteBrowserSnapshot {
        await manager.retryCurrentPath(
            sessionID: sessionID,
            lastKnownPath: lastKnownPath,
            requestID: requestID
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func health(sessionID: RemoteBrowserSessionID) async -> BrowserConnectionHealth {
        await manager.health(sessionID: sessionID)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func browserSessionsSummary() async -> String {
        await manager.sessionsSummary()
    }

    // Compatibility adapter used during migration.
    @available(*, deprecated, message: "Use session-based APIs directly.")
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func listDirectories(remote: RemoteConfig, basePath: String, password: String?) async -> [RemoteDirectoryEntry] {
        let sessionID = await openSession(remote: remote, password: password)
        let requestID = UInt64.random(in: 1..<UInt64.max)
        let snapshot = await listDirectories(sessionID: sessionID, path: basePath, requestID: requestID)
        await closeSession(sessionID)
        return snapshot.entries.map { RemoteDirectoryEntry(name: $0.name, fullPath: $0.fullPath) }
    }

    // Compatibility method for parser tests.
    @available(*, deprecated, message: "Use session-based APIs directly.")
    /// Beginner note: This method is one step in the feature workflow for this file.
    func parseDirectories(from output: String, basePath: String) -> [RemoteDirectoryEntry] {
        let parsed = SFTPDirectoryParser.parse(output: output, basePath: basePath)
        // Parser output already contains directories only.
        return parsed.entries.map { RemoteDirectoryEntry(name: $0.name, fullPath: $0.fullPath) }
    }
}
