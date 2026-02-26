// BEGINNER FILE GUIDE
// Layer: App lifecycle layer
// Purpose: This file controls macOS app startup, window/bootstrap wiring, or application delegate behavior.
// Called by: Usually called by the system (AppKit/SwiftUI) during app launch, reopen, and termination events.
// Calls into: Calls into AppEnvironment, view models, and menu/window controllers.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import SwiftUI

/// Beginner note: Entry point for the menu-bar app. AppDelegate owns lifecycle,
/// menu bar UI, and termination cleanup behavior.
@main
struct MacFuseGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Keep an empty Settings scene so SwiftUI does not create a default app window.
        // Quit and mount teardown behavior is coordinated by AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
