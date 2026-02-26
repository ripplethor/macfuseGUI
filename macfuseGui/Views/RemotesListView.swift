// BEGINNER FILE GUIDE
// Layer: SwiftUI view layer
// Purpose: This file defines visual layout and interaction controls shown to the user.
// Called by: Instantiated by parent views, window controllers, or app bootstrap code.
// Calls into: Reads observed state from view models and triggers callbacks for actions.
// Concurrency: Contains async functions; these can suspend and resume without blocking the calling thread.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import SwiftUI

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct RemotesListView: View {
    let remotes: [RemoteConfig]
    let statuses: [UUID: RemoteStatus]
    let badgeStateForRemote: (UUID) -> RemoteStatusBadgeState
    @Binding var selectedRemoteID: UUID?
    let onConnect: (UUID) -> Void
    let onDisconnect: (UUID) -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            List(selection: $selectedRemoteID) {
                ForEach(remotes) { remote in
                    row(remote)
                        .tag(remote.id)
                        .id(remote.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .onValueChange(of: selectedRemoteID) {
                scrollSelectionToTop(using: scrollProxy)
            }
            .onValueChange(of: remotes) {
                scrollSelectionToTop(using: scrollProxy)
            }
        }
    }

    @ViewBuilder
    /// Beginner note: This method is one step in the feature workflow for this file.
    private func row(_ remote: RemoteConfig) -> some View {
        let status = status(for: remote.id)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(remote.displayName)
                    .font(.headline)
                Spacer()
                StatusBadgeView(state: badgeStateForRemote(remote.id))
            }

            Text("\(remote.username)@\(remote.host):\(remote.port)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Remote: \(remote.remoteDirectory)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Local: \(remote.localMountPoint)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = status.lastError, !error.isEmpty {
                Text(shortError(error))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button("Connect") {
                    onConnect(remote.id)
                }
                .disabled(!status.canConnect)
                .accessibilityLabel("Connect to \(remote.displayName)")

                Button("Disconnect") {
                    onDisconnect(remote.id)
                }
                .disabled(!status.canDisconnect)
                .accessibilityLabel("Disconnect from \(remote.displayName)")
            }
        }
        .padding(.vertical, 6)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func shortError(_ message: String) -> String {
        message.collapsedAndTruncatedForDisplay(limit: 180)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func scrollSelectionToTop(using scrollProxy: ScrollViewProxy) {
        guard let selectedRemoteID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            scrollProxy.scrollTo(selectedRemoteID, anchor: .top)
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func status(for remoteID: UUID) -> RemoteStatus {
        statuses[remoteID] ?? .initial
    }
}

private extension View {
    @ViewBuilder
    func onValueChange<Value: Equatable>(
        of value: Value,
        perform action: @escaping () -> Void
    ) -> some View {
        if #available(macOS 14.0, *) {
            onChange(of: value) { _, _ in
                action()
            }
        } else {
            onChange(of: value) { _ in
                action()
            }
        }
    }
}
