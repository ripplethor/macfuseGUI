// BEGINNER FILE GUIDE
// Layer: SwiftUI view layer
// Purpose: This file defines visual layout and interaction controls shown to the user.
// Called by: Instantiated by parent views, window controllers, or app bootstrap code.
// Calls into: Reads observed state from view models and triggers callbacks for actions.
// Concurrency: Runs on MainActor for UI-safe state updates; this means logic is serialized on the main actor context.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import AppKit
import SwiftUI

// RemoteEditorView is used for both "Add" and "Edit" flows.
// It edits a draft model first, then commits to persistent store only on Save.
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemoteEditorView: View {
    @StateObject private var viewModel: RemoteEditorViewModel
    @ObservedObject private var remotesViewModel: RemotesViewModel
    private let onComplete: (UUID?) -> Void

    // Remote-browser sheet state.
    @State private var showRemoteBrowser = false
    @State private var browserSessionID: RemoteBrowserSessionID?
    @State private var browserViewModel: RemoteBrowserViewModel?
    @State private var preparingRemoteBrowser = false
    @State private var showPassword = false

    /// Beginner note: Initializers create valid state before any other method is used.
    init(
        initialDraft: RemoteDraft,
        remotesViewModel: RemotesViewModel,
        onComplete: @escaping (UUID?) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: RemoteEditorViewModel(draft: initialDraft))
        _remotesViewModel = ObservedObject(wrappedValue: remotesViewModel)
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.isEditingExistingRemote ? "Edit Remote" : "Add Remote")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            Form {
                Section("Connection") {
                    TextField("Display name", text: $viewModel.draft.displayName)
                    TextField("Host / IP", text: $viewModel.draft.host)
                    TextField("Port", value: $viewModel.draft.port, formatter: Self.portFormatter)
                    TextField("Username", text: $viewModel.draft.username)

                    Picker("Authentication", selection: $viewModel.draft.authMode) {
                        ForEach(RemoteAuth.allCases) { auth in
                            Text(auth.displayName).tag(auth)
                        }
                    }

                    if viewModel.draft.authMode == .privateKey {
                        HStack {
                            TextField("Private key path", text: $viewModel.draft.privateKeyPath)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse…", action: pickPrivateKey)
                        }
                        Text("Use key-based auth when possible. It is more reliable than password mode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // Switching between SecureField/TextField intentionally reuses same draft value.
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $viewModel.draft.password)
                                } else {
                                    SecureField("Password", text: $viewModel.draft.password)
                                }
                            }
                            .textFieldStyle(.roundedBorder)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .help(showPassword ? "Hide password" : "Show password")
                        }
                        Text("Password is stored securely in macOS Keychain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Auto-connect on app launch", isOn: $viewModel.draft.autoConnectOnLaunch)
                        .help("Automatically connect this remote when the app starts.")
                }

                Section("Paths") {
                    HStack {
                        TextField("Remote directory", text: $viewModel.draft.remoteDirectory)
                        Button("Browse Remote…") {
                            openRemoteBrowser()
                        }
                        .disabled(!canBrowseRemote || preparingRemoteBrowser)
                    }

                    if !canBrowseRemote {
                        Text("Enter host and username to enable remote directory browsing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if preparingRemoteBrowser {
                        // Clear feedback that session bootstrap is in progress.
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Preparing browser session…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        TextField("Local mount point", text: $viewModel.draft.localMountPoint)
                        Button("Browse Folder…", action: pickLocalFolder)
                    }
                }
            }

            if !viewModel.validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Please fix the following:")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red)
                    ForEach(viewModel.validationErrors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 4)
            }

            if viewModel.isTestingConnection {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Testing connection…")
                        .font(.callout)
                }
            } else if let testMessage = viewModel.testResultMessage, !testMessage.isEmpty {
                Text(testMessage)
                    .font(.callout)
                    .foregroundStyle(viewModel.testResultIsSuccess ? .green : .red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: closeEditor)
                    .keyboardShortcut(.cancelAction)
                    .disabled(viewModel.isSaving || viewModel.isTestingConnection)

                Button("Test Connection") {
                    Task { await viewModel.runConnectionTest(using: remotesViewModel) }
                }
                .disabled(viewModel.isSaving || viewModel.isTestingConnection)

                Button("Save") {
                    if let id = viewModel.save(using: remotesViewModel) {
                        onComplete(id)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isSaving || viewModel.isTestingConnection)
            }
        }
        .padding(18)
        .frame(minWidth: 700, minHeight: 560)
        .overlay(alignment: .topTrailing) {
            Button(action: closeEditor) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close without saving")
            .help("Close without saving")
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $showRemoteBrowser) {
            Group {
                if let browserViewModel {
                    RemoteBrowserView(
                        viewModel: browserViewModel,
                        onSelect: { selectedPath in
                            viewModel.draft.remoteDirectory = selectedPath
                            showRemoteBrowser = false
                        },
                        onCancel: {
                            showRemoteBrowser = false
                        }
                    )
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing browser session…")
                    }
                }
            }
            .onDisappear {
                // Close browser session whenever sheet closes to avoid leaked transport sessions.
                guard let browserSessionID else {
                    return
                }
                Task { @MainActor in
                    await remotesViewModel.stopBrowserSession(id: browserSessionID)
                    if self.browserSessionID == browserSessionID {
                        self.browserSessionID = nil
                    }
                    self.browserViewModel = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .forceQuitRequested)) { _ in
            showRemoteBrowser = false
        }
    }

    private var canBrowseRemote: Bool {
        !viewModel.draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func closeEditor() {
        onComplete(nil)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func openRemoteBrowser() {
        preparingRemoteBrowser = true
        Task { @MainActor in
            defer { preparingRemoteBrowser = false }
            do {
                // Start dedicated browser session for this editor sheet.
                let sessionID = try await remotesViewModel.startBrowserSession(for: viewModel.draft)
                let browserModel = RemoteBrowserViewModel(
                    sessionID: sessionID,
                    initialPath: viewModel.draft.remoteDirectory,
                    initialFavorites: remotesViewModel.browserFavorites(for: viewModel.draft),
                    initialRecents: remotesViewModel.browserRecents(for: viewModel.draft),
                    username: viewModel.draft.username,
                    remotesViewModel: remotesViewModel,
                    onPathMemoryChanged: { favorites, recents in
                        // Keep draft memory in sync live; saved remotes persist on Save.
                        viewModel.draft.favoriteRemoteDirectories = favorites
                        viewModel.draft.recentRemoteDirectories = recents
                    }
                )
                self.browserViewModel = browserModel
                self.browserSessionID = sessionID
                showRemoteBrowser = true
            } catch {
                remotesViewModel.alertMessage = error.localizedDescription
            }
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func pickPrivateKey() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.title = "Select SSH Private Key"
        presentOpenPanel(panel) { url in
            viewModel.draft.privateKeyPath = url.path
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func pickLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        // Avoid resolving potentially stale alias targets on network/removable volumes.
        panel.resolvesAliases = false
        panel.title = "Select Local Mount Point"
        panel.prompt = "Select Folder"
        panel.message = "Choose or create a folder to use as the local SSHFS mount point."
        // Force a safe local start location. Relying on panel's remembered last
        // folder can hang when that location is stale/unreachable.
        panel.directoryURL = preferredLocalFolderPickerStartURL()
        presentOpenPanel(panel) { url in
            viewModel.draft.localMountPoint = url.path
        }
    }

    /// Beginner note: Present picker panels asynchronously so reconnect/status
    /// work does not deadlock with a synchronous modal loop.
    private func presentOpenPanel(_ panel: NSOpenPanel, onSelect: @escaping (URL) -> Void) {
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            onSelect(url)
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    /// Beginner note: This method picks a local folder picker start location that
    /// avoids stale/unreachable paths while still being useful for mount selection.
    private func preferredLocalFolderPickerStartURL() -> URL {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
        let rawMountPoint = viewModel.draft.localMountPoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawMountPoint.isEmpty, rawMountPoint.hasPrefix("/") else {
            return homeURL
        }

        let parent = URL(fileURLWithPath: rawMountPoint, isDirectory: true)
            .standardizedFileURL
            .deletingLastPathComponent()
        let parentPath = parent.path
        let homePath = homeURL.path

        // Stay within the user's home directory for predictable local performance.
        if parentPath == homePath || parentPath.hasPrefix(homePath + "/") {
            return parent
        }

        return homeURL
    }

    private static let portFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 65535
        return formatter
    }()
}
