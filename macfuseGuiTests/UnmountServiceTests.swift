// BEGINNER FILE GUIDE
// Layer: Automated test layer
// Purpose: This file verifies production behavior and protects against regressions when code changes.
// Called by: Executed by XCTest during xcodebuild test or IDE test runs.
// Calls into: Calls production code and test fixtures with deterministic assertions.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import XCTest
@testable import macfuseGui

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class UnmountServiceTests: XCTestCase {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParseBlockingProcessesFromFieldModeOutput() {
        let service = makeService()
        let output = """
        p123
        cFinder
        n/Users/philip/MACFUSE-REMOTES/SouthAfrica
        p456
        ccode
        n/Users/philip/MACFUSE-REMOTES/SouthAfrica/index.js
        """

        let blockers = service.parseBlockingProcesses(from: output)
        XCTAssertEqual(blockers.count, 2)
        XCTAssertEqual(blockers[0], UnmountBlockingProcess(command: "Finder", pid: 123, path: "/Users/philip/MACFUSE-REMOTES/SouthAfrica"))
        XCTAssertEqual(blockers[1], UnmountBlockingProcess(command: "code", pid: 456, path: "/Users/philip/MACFUSE-REMOTES/SouthAfrica/index.js"))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParseBlockingProcessesFromTableOutput() {
        let service = makeService()
        let output = """
        COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        Finder    321 philip cwd    DIR    1,4      96    2 /Users/philip/MACFUSE-REMOTES/SouthAfrica
        code      654 philip txt    REG    1,4    2048    3 /Users/philip/MACFUSE-REMOTES/SouthAfrica/app.js
        """

        let blockers = service.parseBlockingProcesses(from: output)
        XCTAssertEqual(blockers.count, 2)
        XCTAssertEqual(blockers[0], UnmountBlockingProcess(command: "Finder", pid: 321, path: "/Users/philip/MACFUSE-REMOTES/SouthAfrica"))
        XCTAssertEqual(blockers[1], UnmountBlockingProcess(command: "code", pid: 654, path: "/Users/philip/MACFUSE-REMOTES/SouthAfrica/app.js"))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func makeService() -> UnmountService {
        UnmountService(
            runner: ProcessRunner(),
            diagnostics: DiagnosticsService(),
            mountStateParser: MountStateParser()
        )
    }
}
