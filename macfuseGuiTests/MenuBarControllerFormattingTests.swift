// BEGINNER FILE GUIDE
// Layer: Automated test layer
// Purpose: This file verifies production behavior and protects against regressions when code changes.
// Called by: Executed by XCTest during xcodebuild test or IDE test runs.
// Calls into: Calls production code and test fixtures with deterministic assertions.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation
import XCTest
@testable import macfuseGui

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class MenuBarControllerFormattingTests: XCTestCase {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecoveryReasonDisplayTextMappings() {
        XCTAssertEqual(MenuBarController.recoveryReasonDisplayText("wake"), "after wake")
        XCTAssertEqual(MenuBarController.recoveryReasonDisplayText("network-restored"), "after network restore")
        XCTAssertEqual(MenuBarController.recoveryReasonDisplayText("periodic"), "periodic")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testFormattedElapsedTextOutput() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            MenuBarController.formattedElapsedText(
                since: now.addingTimeInterval(-3.45),
                now: now
            ),
            "3.5s"
        )
        XCTAssertEqual(
            MenuBarController.formattedElapsedText(
                since: now.addingTimeInterval(-12),
                now: now
            ),
            "12s"
        )
        XCTAssertEqual(
            MenuBarController.formattedElapsedText(
                since: now.addingTimeInterval(-125),
                now: now
            ),
            "2m 5s"
        )
        XCTAssertEqual(
            MenuBarController.formattedElapsedText(
                since: now.addingTimeInterval(5),
                now: now
            ),
            "0.0s"
        )
    }
}
