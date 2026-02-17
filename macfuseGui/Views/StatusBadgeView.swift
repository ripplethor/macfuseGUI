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
struct StatusBadgeView: View {
    private let statusLabel: String
    private let color: Color

    /// Beginner note: Initializers create valid state before any other method is used.
    init(stateRawValue: String) {
        switch stateRawValue {
        case "connected":
            statusLabel = "Connected"
            color = .green
        case "reconnecting":
            statusLabel = "Re-connecting"
            color = .orange
        case "connecting":
            statusLabel = "Connecting"
            color = .orange
        case "disconnecting":
            statusLabel = "Disconnecting"
            color = .orange
        case "error":
            statusLabel = "Error"
            color = .red
        default:
            statusLabel = "Disconnected"
            color = .secondary
        }
    }

    var body: some View {
        Text(statusLabel)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
