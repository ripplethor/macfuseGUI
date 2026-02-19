// BEGINNER FILE GUIDE
// Layer: Core service layer
// Purpose: This file performs non-UI work such as mount commands, process execution, validation, persistence, or diagnostics.
// Called by: Called by view models to execute user actions and background recovery work.
// Calls into: May call system APIs, external tools, Keychain, filesystem, and helper services.
// Concurrency: Runs on MainActor for UI-safe state updates; this means logic is serialized on the main actor context.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

@MainActor
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
protocol RemoteStore {
    var storageURL: URL { get }
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func load() throws -> [RemoteConfig]
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func save(_ remotes: [RemoteConfig]) throws
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func upsert(_ remote: RemoteConfig) throws
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func delete(id: UUID) throws
}

@MainActor
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class JSONRemoteStore: RemoteStore {
    let storageURL: URL
    private let fileManager: FileManager

    /// Beginner note: Initializers create valid state before any other method is used.
    init(
        fileManager: FileManager = .default,
        storageURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            // Defensive fallback: FileManager should return Application Support URL, but avoid crashing if it doesn't.
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            self.storageURL = appSupport
                .appendingPathComponent("macfuseGui", isDirectory: true)
                .appendingPathComponent("remotes.json", isDirectory: false)
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func load() throws -> [RemoteConfig] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            return try decoder.decode([RemoteConfig].self, from: data)
        } catch {
            throw AppError.persistenceError("Failed to load remotes: \(error.localizedDescription)")
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func save(_ remotes: [RemoteConfig]) throws {
        let parent = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(remotes)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            throw AppError.persistenceError("Failed to save remotes: \(error.localizedDescription)")
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func upsert(_ remote: RemoteConfig) throws {
        var remotes = try load()
        if let index = remotes.firstIndex(where: { $0.id == remote.id }) {
            remotes[index] = remote
        } else {
            remotes.append(remote)
        }
        try save(remotes)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func delete(id: UUID) throws {
        let remotes = try load().filter { $0.id != id }
        try save(remotes)
    }
}
