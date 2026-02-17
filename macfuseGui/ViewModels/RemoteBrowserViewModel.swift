// BEGINNER FILE GUIDE
// Layer: View model orchestration layer
// Purpose: This file transforms service-level behavior into UI-ready state and user actions.
// Called by: Called by SwiftUI views and menu controllers in response to user input.
// Calls into: Calls into services and publishes state changes back to the UI.
// Concurrency: Runs on MainActor for UI-safe state updates; this means logic is serialized on the main actor context.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

// These view states are intentionally coarse UI states.
// Fine-grained transport details live in BrowserConnectionHealth + diagnostics.
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum BrowserViewState: String, Sendable {
    case idle
    case loadingFirstPage
    case ready
    case degradedWithCache
    case recovering
    case fatal
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum BrowserSortMode: String, CaseIterable, Sendable {
    case name
    case modified
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemotePathBreadcrumb: Identifiable, Equatable {
    let title: String
    let fullPath: String

    var id: String { fullPath }
}

@MainActor
// RemoteBrowserViewModel receives snapshots from browser sessions and turns them into
// UI state for table rows, banners, footer text, and retry behavior.
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class RemoteBrowserViewModel: ObservableObject {
    // Published values drive SwiftUI updates.
    @Published private(set) var viewState: BrowserViewState = .idle
    @Published private(set) var currentPath: String
    @Published private(set) var entries: [RemoteDirectoryItem] = []
    @Published private(set) var health: BrowserConnectionHealth = .connecting
    @Published private(set) var isStale: Bool = false
    @Published private(set) var isConfirmedEmpty: Bool = false
    @Published private(set) var statusMessage: String?
    @Published var searchText: String = ""
    @Published var sortMode: BrowserSortMode = .name
    @Published var selectedItemID: RemoteDirectoryItem.ID?
    @Published private(set) var favorites: [String]
    @Published private(set) var recents: [String]

    private let sessionID: RemoteBrowserSessionID
    private let remotesViewModel: RemotesViewModel
    private let username: String
    private let onPathMemoryChanged: (([String], [String]) -> Void)?
    // Monotonic request ID prevents stale responses from clobbering newer navigation.
    private var latestRequestID: UInt64 = 0
    private var healthTask: Task<Void, Never>?
    private var degradedRefreshTask: Task<Void, Never>?
    private var requestInFlight = false

    /// Beginner note: Initializers create valid state before any other method is used.
    init(
        sessionID: RemoteBrowserSessionID,
        initialPath: String,
        initialFavorites: [String],
        initialRecents: [String],
        username: String,
        remotesViewModel: RemotesViewModel,
        onPathMemoryChanged: (([String], [String]) -> Void)? = nil
    ) {
        self.sessionID = sessionID
        self.currentPath = BrowserPathNormalizer.normalize(path: initialPath)
        self.favorites = RemotesViewModel.normalizePathMemoryCollection(
            initialFavorites,
            limit: RemotesViewModel.favoritesLimit
        )
        self.recents = RemotesViewModel.normalizePathMemoryCollection(
            initialRecents,
            limit: RemotesViewModel.recentsLimit
        )
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "user" : username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.remotesViewModel = remotesViewModel
        self.onPathMemoryChanged = onPathMemoryChanged
    }

    /// Beginner note: Deinitializer runs during teardown to stop background work and free resources.
    deinit {
        healthTask?.cancel()
        degradedRefreshTask?.cancel()
    }

    var visibleEntries: [RemoteDirectoryItem] {
        let filtered = entries.filter { entry in
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            entry.name.localizedCaseInsensitiveContains(searchText)
        }

        switch sortMode {
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .modified:
            return filtered.sorted { lhs, rhs in
                switch (lhs.modifiedAt, rhs.modifiedAt) {
                case let (l?, r?):
                    if l == r {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return l > r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
        }
    }

    var breadcrumbs: [RemotePathBreadcrumb] {
        let normalized = BrowserPathNormalizer.normalize(path: currentPath)
        if normalized == "/" {
            return [RemotePathBreadcrumb(title: "/", fullPath: "/")]
        }
        if normalized == "~" {
            return [RemotePathBreadcrumb(title: "~", fullPath: "~")]
        }

        if normalized.hasPrefix("~/") {
            let tail = String(normalized.dropFirst(2))
            let components = tail.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            var result: [RemotePathBreadcrumb] = [RemotePathBreadcrumb(title: "~", fullPath: "~")]
            var cursor = "~"
            for component in components {
                cursor += "/\(component)"
                result.append(RemotePathBreadcrumb(title: component, fullPath: cursor))
            }
            return result
        }

        let components = normalized.dropFirst().split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var result: [RemotePathBreadcrumb] = [RemotePathBreadcrumb(title: "/", fullPath: "/")]
        var cursor = ""
        for (index, component) in components.enumerated() {
            if index == 0, BrowserPathNormalizer.isWindowsDriveComponent(component) {
                cursor = "/\(component)/"
            } else {
                cursor += "/\(component)"
            }
            result.append(
                RemotePathBreadcrumb(
                    title: component,
                    fullPath: BrowserPathNormalizer.normalize(path: cursor)
                )
            )
        }
        return result
    }

    var roots: [String] {
        BrowserPathNormalizer.rootCandidates(for: username)
    }

    var isRecovering: Bool {
        health.state == .reconnecting || health.state == .degraded || health.state == .connecting
    }

    var itemCountText: String {
        let count = visibleEntries.count
        return count == 1 ? "1 folder" : "\(count) folders"
    }

    var healthText: String {
        switch health.state {
        case .connecting:
            return "Connecting…"
        case .healthy:
            return "Connected"
        case .degraded:
            return "Degraded"
        case .reconnecting:
            return "Reconnecting…"
        case .failed:
            return "Connection Failed"
        case .closed:
            return "Closed"
        }
    }

    var lastSuccessText: String {
        guard let timestamp = health.lastSuccessAt else {
            return "Last success: -"
        }

        return "Last success: \(Self.statusDateFormatter.string(from: timestamp))"
    }

    var latencyText: String {
        guard let latencyMs = health.lastLatencyMs else {
            return "Latency: -"
        }
        return "Latency: \(latencyMs) ms"
    }

    var hasVisibleData: Bool {
        !visibleEntries.isEmpty
    }

    var shouldShowConfirmedEmptyState: Bool {
        health.state == .healthy && isConfirmedEmpty && visibleEntries.isEmpty
    }

    var canRetryNow: Bool {
        health.state == .degraded || health.state == .reconnecting || health.state == .failed || viewState == .degradedWithCache || viewState == .recovering
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func loadInitial() async {
        // First load also starts background health polling + degraded auto-retry loop.
        viewState = .loadingFirstPage
        await loadPath(currentPath, reason: "initial")
        startHealthLoop()
        startDegradedRefreshLoop()
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func refresh() async {
        await loadPath(currentPath, reason: "refresh")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func retryNow() async {
        await retryCurrentPath(reason: "manual-retry")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func goTo(path: String) async {
        await loadPath(path, reason: "navigate")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func goRoot() async {
        await loadPath("/", reason: "root")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func goUp() async {
        guard !requestInFlight else {
            return
        }

        // Parent-path navigation goes through dedicated service API.
        latestRequestID += 1
        let requestID = latestRequestID
        requestInFlight = true
        let snapshot = await remotesViewModel.goUpBrowserPath(
            sessionID: sessionID,
            currentPath: currentPath,
            requestID: requestID
        )
        requestInFlight = false
        apply(snapshot: snapshot, reason: "up")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func open(_ item: RemoteDirectoryItem) async {
        await loadPath(item.fullPath, reason: "open")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func toggleFavoriteForCurrentPath() {
        let normalized = BrowserPathNormalizer.normalize(path: currentPath)
        if let idx = favorites.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(normalized, at: 0)
            favorites = RemotesViewModel.normalizePathMemoryCollection(
                favorites,
                limit: RemotesViewModel.favoritesLimit
            )
        }
        // Persist favorites/recents immediately so editor/session state stays in sync.
        persistPathMemory()
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func selectCurrentPath() -> String {
        addRecentPath(currentPath)
        return currentPath
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func select(_ item: RemoteDirectoryItem) -> String {
        let normalized = BrowserPathNormalizer.normalize(path: item.fullPath)
        addRecentPath(normalized)
        return normalized
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    func closeSession() async {
        healthTask?.cancel()
        healthTask = nil
        degradedRefreshTask?.cancel()
        degradedRefreshTask = nil
        await remotesViewModel.stopBrowserSession(id: sessionID)
    }

    var isCurrentPathFavorite: Bool {
        favorites.contains { $0.caseInsensitiveCompare(currentPath) == .orderedSame }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    private func loadPath(_ path: String, reason: String) async {
        guard !requestInFlight else {
            return
        }

        latestRequestID += 1
        let requestID = latestRequestID
        let normalized = BrowserPathNormalizer.normalize(path: path)

        if entries.isEmpty {
            viewState = .loadingFirstPage
        } else {
            viewState = .recovering
        }

        requestInFlight = true
        let snapshot = await remotesViewModel.loadBrowserPath(
            sessionID: sessionID,
            path: normalized,
            requestID: requestID
        )
        requestInFlight = false
        // apply(...) enforces request-ordering and state transitions in one place.
        apply(snapshot: snapshot, reason: reason)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async: it can suspend and resume later without blocking a thread.
    private func retryCurrentPath(reason: String) async {
        guard !requestInFlight else {
            return
        }

        latestRequestID += 1
        let requestID = latestRequestID
        requestInFlight = true
        let snapshot = await remotesViewModel.retryCurrentBrowserPath(
            sessionID: sessionID,
            requestID: requestID
        )
        requestInFlight = false
        apply(snapshot: snapshot, reason: reason)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func apply(snapshot: RemoteBrowserSnapshot, reason: String) {
        // Ignore older snapshot responses if a newer request already started.
        guard snapshot.requestID >= latestRequestID else {
            return
        }
        latestRequestID = snapshot.requestID

        currentPath = BrowserPathNormalizer.normalize(path: snapshot.path)
        health = snapshot.health
        isStale = snapshot.isStale
        isConfirmedEmpty = snapshot.isConfirmedEmpty
        statusMessage = snapshot.message

        let directoryEntries = snapshot.entries.filter(\.isDirectory)
        if !directoryEntries.isEmpty {
            entries = directoryEntries
        } else if snapshot.isConfirmedEmpty && !snapshot.isStale {
            // Only clear list on confirmed healthy empty folder.
            entries = []
        } else if entries.isEmpty {
            entries = []
        }

        if snapshot.health.state == .failed && entries.isEmpty {
            viewState = .fatal
        } else if snapshot.isStale {
            // Stale data means show cache while recovery continues.
            viewState = entries.isEmpty ? .recovering : .degradedWithCache
        } else if snapshot.health.state == .degraded {
            viewState = entries.isEmpty ? .recovering : .degradedWithCache
        } else if snapshot.health.state == .reconnecting || snapshot.health.state == .connecting {
            viewState = .recovering
        } else {
            viewState = .ready
            // Browsed paths become recents only on healthy ready state.
            addRecentPath(currentPath)
        }

        if reason == "open" || reason == "navigate" || reason == "root" || reason == "up" {
            selectedItemID = nil
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func persistPathMemory() {
        onPathMemoryChanged?(favorites, recents)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func addRecentPath(_ path: String) {
        let updated = RemotesViewModel.pushRecentRemotePath(
            path,
            existing: recents,
            limit: RemotesViewModel.recentsLimit
        )
        guard updated != recents else {
            return
        }
        recents = updated
        persistPathMemory()
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func startHealthLoop() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            guard let self else {
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled {
                    break
                }
                let latest = await remotesViewModel.browserHealth(sessionID: sessionID)
                await MainActor.run {
                    self.health = latest
                    // If backend moved to reconnecting while UI looked ready, reflect it.
                    if latest.state == .reconnecting && self.viewState == .ready {
                        self.viewState = .recovering
                    }
                }
            }
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func startDegradedRefreshLoop() {
        degradedRefreshTask?.cancel()
        degradedRefreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if Task.isCancelled {
                    break
                }

                let shouldRetry = await MainActor.run {
                    self.health.state != .healthy && self.health.state != .closed
                }
                guard shouldRetry else {
                    continue
                }

                // Automatic retry while degraded avoids requiring constant user refresh clicks.
                await self.retryCurrentPath(reason: "auto-retry")
            }
        }
    }

    private static let statusDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
