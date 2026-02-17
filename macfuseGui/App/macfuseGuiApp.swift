// BEGINNER FILE GUIDE
// Layer: App lifecycle layer
// Purpose: This file controls macOS app startup, window/bootstrap wiring, or application delegate behavior.
// Called by: Usually called by the system (AppKit/SwiftUI) during app launch, reopen, and termination events.
// Calls into: Calls into AppEnvironment, view models, and menu/window controllers.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import SwiftUI

@main
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct macfuseGuiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
