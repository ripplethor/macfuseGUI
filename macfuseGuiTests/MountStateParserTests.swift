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
final class MountStateParserTests: XCTestCase {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParseMountOutput() {
        let output = """
        /dev/disk3s1 on / (apfs, local, read-only, journaled)
        dev@host:/remote/path on /Volumes/testmount (osxfuse_sshfs, nodev, nosuid, mounted by philip)
        """

        let parser = MountStateParser()
        let records = parser.parseMountOutput(output)

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[1].source, "dev@host:/remote/path")
        XCTAssertEqual(records[1].mountPoint, "/Volumes/testmount")
        XCTAssertEqual(records[1].filesystemType, "osxfuse_sshfs")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecordLookupByMountPoint() {
        let parser = MountStateParser()
        let records = [
            MountRecord(source: "dev@host:/a", mountPoint: "/Volumes/a", filesystemType: "osxfuse_sshfs")
        ]

        let found = parser.record(forMountPoint: "/Volumes/a", from: records)
        XCTAssertNotNil(found)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParsesEscapedMountPoint() {
        let output = """
        dev@host:/remote\\040path on /Users/philip/MACFUSE\\040REMOTES/Test\\040Space (macfuse_sshfs, nodev)
        """

        let parser = MountStateParser()
        let records = parser.parseMountOutput(output)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].source, "dev@host:/remote path")
        XCTAssertEqual(records[0].mountPoint, "/Users/philip/MACFUSE REMOTES/Test Space")
        XCTAssertNotNil(parser.record(forMountPoint: "/Users/philip/MACFUSE REMOTES/Test Space", from: records))
    }
}
