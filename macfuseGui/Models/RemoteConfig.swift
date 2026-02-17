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
struct RemoteConfig: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var displayName: String
    var host: String
    var port: Int
    var username: String
    var authMode: RemoteAuth
    var privateKeyPath: String?
    var remoteDirectory: String
    var localMountPoint: String
    var autoConnectOnLaunch: Bool
    var favoriteRemoteDirectories: [String]
    var recentRemoteDirectories: [String]

    /// Beginner note: This type groups related state and behavior for one part of the app.
    /// Read stored properties first, then follow methods top-to-bottom to understand flow.
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case host
        case port
        case username
        case authMode
        case privateKeyPath
        case remoteDirectory
        case localMountPoint
        case autoConnectOnLaunch
        case favoriteRemoteDirectories
        case recentRemoteDirectories
    }

    /// Beginner note: Initializers create valid state before any other method is used.
    init(
        id: UUID = UUID(),
        displayName: String,
        host: String,
        port: Int = 22,
        username: String,
        authMode: RemoteAuth,
        privateKeyPath: String? = nil,
        remoteDirectory: String,
        localMountPoint: String,
        autoConnectOnLaunch: Bool = false,
        favoriteRemoteDirectories: [String] = [],
        recentRemoteDirectories: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.port = port
        self.username = username
        self.authMode = authMode
        self.privateKeyPath = privateKeyPath
        self.remoteDirectory = remoteDirectory
        self.localMountPoint = localMountPoint
        self.autoConnectOnLaunch = autoConnectOnLaunch
        self.favoriteRemoteDirectories = favoriteRemoteDirectories
        self.recentRemoteDirectories = recentRemoteDirectories
    }

    /// Beginner note: Initializers create valid state before any other method is used.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 22
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        authMode = try container.decodeIfPresent(RemoteAuth.self, forKey: .authMode) ?? .privateKey
        privateKeyPath = try container.decodeIfPresent(String.self, forKey: .privateKeyPath)
        remoteDirectory = try container.decodeIfPresent(String.self, forKey: .remoteDirectory) ?? "/"
        localMountPoint = try container.decodeIfPresent(String.self, forKey: .localMountPoint) ?? ""
        autoConnectOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .autoConnectOnLaunch) ?? false
        favoriteRemoteDirectories = try container.decodeIfPresent([String].self, forKey: .favoriteRemoteDirectories) ?? []
        recentRemoteDirectories = try container.decodeIfPresent([String].self, forKey: .recentRemoteDirectories) ?? []
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encode(authMode, forKey: .authMode)
        try container.encodeIfPresent(privateKeyPath, forKey: .privateKeyPath)
        try container.encode(remoteDirectory, forKey: .remoteDirectory)
        try container.encode(localMountPoint, forKey: .localMountPoint)
        try container.encode(autoConnectOnLaunch, forKey: .autoConnectOnLaunch)
        try container.encode(favoriteRemoteDirectories, forKey: .favoriteRemoteDirectories)
        try container.encode(recentRemoteDirectories, forKey: .recentRemoteDirectories)
    }

    static let sample = RemoteConfig(
        displayName: "Example Server",
        host: "example.com",
        username: "dev",
        authMode: .privateKey,
        privateKeyPath: NSHomeDirectory() + "/.ssh/id_ed25519",
        remoteDirectory: "/srv/data",
        localMountPoint: "/Volumes/example",
        autoConnectOnLaunch: false,
        favoriteRemoteDirectories: [],
        recentRemoteDirectories: []
    )
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteDraft: Equatable, Sendable {
    var id: UUID?
    var displayName: String = ""
    var host: String = ""
    var port: Int = 22
    var username: String = ""
    var authMode: RemoteAuth = .privateKey
    var privateKeyPath: String = ""
    var password: String = ""
    var remoteDirectory: String = "/"
    var localMountPoint: String = ""
    var autoConnectOnLaunch: Bool = false
    var favoriteRemoteDirectories: [String] = []
    var recentRemoteDirectories: [String] = []

    static let empty = RemoteDraft()

    /// Beginner note: Initializers create valid state before any other method is used.
    init(
        id: UUID? = nil,
        displayName: String = "",
        host: String = "",
        port: Int = 22,
        username: String = "",
        authMode: RemoteAuth = .privateKey,
        privateKeyPath: String = "",
        password: String = "",
        remoteDirectory: String = "/",
        localMountPoint: String = "",
        autoConnectOnLaunch: Bool = false,
        favoriteRemoteDirectories: [String] = [],
        recentRemoteDirectories: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.port = port
        self.username = username
        self.authMode = authMode
        self.privateKeyPath = privateKeyPath
        self.password = password
        self.remoteDirectory = remoteDirectory
        self.localMountPoint = localMountPoint
        self.autoConnectOnLaunch = autoConnectOnLaunch
        self.favoriteRemoteDirectories = favoriteRemoteDirectories
        self.recentRemoteDirectories = recentRemoteDirectories
    }

    /// Beginner note: Initializers create valid state before any other method is used.
    init(remote: RemoteConfig, password: String = "") {
        self.id = remote.id
        self.displayName = remote.displayName
        self.host = remote.host
        self.port = remote.port
        self.username = remote.username
        self.authMode = remote.authMode
        self.privateKeyPath = remote.privateKeyPath ?? ""
        self.password = password
        self.remoteDirectory = remote.remoteDirectory
        self.localMountPoint = remote.localMountPoint
        self.autoConnectOnLaunch = remote.autoConnectOnLaunch
        self.favoriteRemoteDirectories = remote.favoriteRemoteDirectories
        self.recentRemoteDirectories = remote.recentRemoteDirectories
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func asRemoteConfig() -> RemoteConfig {
        RemoteConfig(
            id: id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            authMode: authMode,
            privateKeyPath: privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines),
            remoteDirectory: remoteDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
            localMountPoint: localMountPoint.trimmingCharacters(in: .whitespacesAndNewlines),
            autoConnectOnLaunch: autoConnectOnLaunch,
            favoriteRemoteDirectories: favoriteRemoteDirectories,
            recentRemoteDirectories: recentRemoteDirectories
        )
    }
}
