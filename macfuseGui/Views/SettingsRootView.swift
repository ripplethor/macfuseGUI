// BEGINNER FILE GUIDE
// Layer: SwiftUI view layer
// Purpose: This file defines visual layout and interaction controls shown to the user.
// Called by: Instantiated by parent views, window controllers, or app bootstrap code.
// Calls into: Reads observed state from view models and triggers callbacks for actions.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import SwiftUI

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct SettingsRootView: View {
    @ObservedObject var viewModel: RemotesViewModel

    @State private var activeEditorSession: EditorSession?

    var body: some View {
        VStack(spacing: 0) {
            if let message = viewModel.alertMessage, !message.isEmpty {
                HStack {
                    Text(message)
                        .font(.callout)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.alertMessage = nil
                    }
                    .buttonStyle(.link)
                }
                .padding(10)
                .background(Color.orange.opacity(0.18))
            }

            HStack(spacing: 12) {
                Toggle("Launch At Login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)
                    .help("Open macfuseGui automatically when you log in.")

                if viewModel.launchAtLoginState.requiresApproval {
                    Text("Pending approval in System Settings -> General -> Login Items.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let detail = viewModel.launchAtLoginState.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Remotes")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("Add") {
                            openEditor(
                                with: RemoteDraft(
                                port: 22,
                                authMode: .privateKey,
                                remoteDirectory: "/"
                            )
                            )
                        }
                    }
                    .padding([.top, .horizontal], 12)

                    RemotesListView(
                        remotes: viewModel.remotes,
                        statuses: viewModel.statuses,
                        badgeStateForRemote: { remoteID in
                            viewModel.statusBadgeRawValue(for: remoteID)
                        },
                        selectedRemoteID: $viewModel.selectedRemoteID,
                        onConnect: { id in
                            Task { await viewModel.connect(remoteID: id) }
                        },
                        onDisconnect: { id in
                            Task { await viewModel.disconnect(remoteID: id) }
                        }
                    )
                }
                .frame(minWidth: 430)

                Divider()

                detailPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(18)
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .sheet(item: $activeEditorSession) { session in
            RemoteEditorView(initialDraft: session.draft, remotesViewModel: viewModel) { savedID in
                activeEditorSession = nil
                if let savedID {
                    viewModel.selectedRemoteID = savedID
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .forceQuitRequested)) { _ in
            activeEditorSession = nil
        }
        .onAppear {
            viewModel.refreshLaunchAtLoginState()
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let remote = selectedRemote {
            let status = viewModel.status(for: remote.id)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(remote.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    StatusBadgeView(stateRawValue: viewModel.statusBadgeRawValue(for: remote.id))
                    Spacer()
                }

                Group {
                    Text("Host: \(remote.host)")
                    Text("Port: \(remote.port)")
                    Text("Username: \(remote.username)")
                    Text("Auth: \(remote.authMode.displayName)")
                    Text("Auto-connect on launch: \(remote.autoConnectOnLaunch ? "On" : "Off")")
                    Text("Remote Directory: \(remote.remoteDirectory)")
                    Text("Local Mount Point: \(remote.localMountPoint)")
                }
                .font(.body)

                if let mounted = status.mountedPath {
                    Text("Mounted Path: \(mounted)")
                        .font(.callout)
                        .foregroundStyle(.green)
                }

                if let error = status.lastError, !error.isEmpty {
                    Text("Last Error: \(shortError(error))")
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Edit") {
                        let draft = RemoteDraft(remote: remote)
                        openEditor(with: draft)
                    }

                    Button("Duplicate") {
                        var draft = RemoteDraft(remote: remote)
                        draft.id = nil
                        draft.displayName = duplicateDisplayName(for: remote.displayName)
                        openEditor(with: draft)
                    }

                    Button("Delete") {
                        viewModel.deleteRemote(remote.id)
                    }
                    .foregroundStyle(.red)

                    Button("Refresh") {
                        Task { await viewModel.refreshStatus(remoteID: remote.id) }
                    }

                    Spacer()

                    Button("Connect") {
                        Task { await viewModel.connect(remoteID: remote.id) }
                    }
                    .disabled(!(status.state == .disconnected || status.state == .error || status.state == .disconnecting))

                    Button("Disconnect") {
                        Task { await viewModel.disconnect(remoteID: remote.id) }
                    }
                    .disabled(!(status.state == .connected || status.state == .connecting))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select a remote")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Add a remote or select one from the list to edit connection settings.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var selectedRemote: RemoteConfig? {
        guard let selectedRemoteID = viewModel.selectedRemoteID else {
            return nil
        }
        return viewModel.remotes.first(where: { $0.id == selectedRemoteID })
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func shortError(_ message: String) -> String {
        let collapsed = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if collapsed.count <= 220 {
            return collapsed
        }

        let prefix = collapsed.prefix(220)
        return "\(prefix)…"
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func duplicateDisplayName(for original: String) -> String {
        let base = original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Remote"
            : original.trimmingCharacters(in: .whitespacesAndNewlines)
        let copyBase = "\(base) Copy"

        let existingNames = Set(viewModel.remotes.map { $0.displayName.lowercased() })
        if !existingNames.contains(copyBase.lowercased()) {
            return copyBase
        }

        var index = 2
        while true {
            let candidate = "\(copyBase) \(index)"
            if !existingNames.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func openEditor(with draft: RemoteDraft) {
        activeEditorSession = EditorSession(draft: draft)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.launchAtLoginState.isOnForToggle
            },
            set: { newValue in
                viewModel.setLaunchAtLoginEnabled(newValue)
            }
        )
    }

    /// Beginner note: This type groups related state and behavior for one part of the app.
    /// Read stored properties first, then follow methods top-to-bottom to understand flow.
    private struct EditorSession: Identifiable {
        let id = UUID()
        let draft: RemoteDraft
    }
}
