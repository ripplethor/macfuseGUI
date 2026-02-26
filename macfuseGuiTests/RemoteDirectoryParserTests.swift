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
final class RemoteDirectoryParserTests: XCTestCase {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParsesOnlyDirectories() {
        let listing = """
        drwxr-xr-x    3 user staff        96 Jan 10 11:00 .
        drwxr-xr-x    5 user staff       160 Jan 10 11:00 ..
        drwxr-xr-x    2 user staff        64 Jan 10 11:00 projects
        -rw-r--r--    1 user staff      1024 Jan 10 11:00 notes.txt
        drwxr-xr-x    6 user staff       192 Jan 10 11:00 archive
        """

        let parsed = SFTPDirectoryParser.parse(output: listing, basePath: "/home/user")
        let entries = parsed.entries.filter(\.isDirectory)
        XCTAssertEqual(entries.map(\.name).sorted(), ["archive", "projects"])
        XCTAssertEqual(entries.first(where: { $0.name == "projects" })?.fullPath, "/home/user/projects")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParsesWindowsStyleDirectoryListing() {
        let listing = """
        07/18/2025  10:21 AM    <DIR>          Documents
        07/18/2025  10:21 AM    <DIR>          Downloads
        07/18/2025  10:21 AM                  1024 notes.txt
        """

        let parsed = SFTPDirectoryParser.parse(output: listing, basePath: "/C:/Users/dev")
        let entries = parsed.entries.filter(\.isDirectory)
        XCTAssertEqual(entries.map(\.name).sorted(), ["Documents", "Downloads"])
        XCTAssertEqual(entries.first(where: { $0.name == "Documents" })?.fullPath, "/C:/Users/dev/Documents")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParsesDirectoriesWithDoubleColonWindowsBasePath() {
        let listing = """
        07/18/2025  10:21 AM    <DIR>          wwwroot
        """

        let parsed = SFTPDirectoryParser.parse(output: listing, basePath: "/D::")
        let entries = parsed.entries.filter(\.isDirectory)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].fullPath, "/D:/wwwroot")
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testParsesWindowsStyleDirectoryListingWith24HourClock() {
        let listing = """
        18/07/2025  22:21    <DIR>          Backups
        """

        let parsed = SFTPDirectoryParser.parse(output: listing, basePath: "/C:/Users/dev")
        let entries = parsed.entries.filter(\.isDirectory)
        XCTAssertEqual(entries.map(\.name), ["Backups"])
        XCTAssertNotNil(entries.first?.modifiedAt)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testCaseDistinctDirectoriesAreNotDeduplicated() {
        let listing = """
        drwxr-xr-x    2 user staff        64 Jan 10 11:00 Docs
        drwxr-xr-x    2 user staff        64 Jan 10 11:00 docs
        """

        let parsed = SFTPDirectoryParser.parse(output: listing, basePath: "/home/user")
        let entries = parsed.entries.filter(\.isDirectory)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.map(\.name)), Set(["Docs", "docs"]))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testLibSSH2ClassifierRecognizesWindowsDirMarkers() {
        let windowsDir = classify(longEntry: "07/18/2025  10:21 AM    <DIR>          wwwroot")
        let posixDir = classify(longEntry: "drwxr-xr-x 2 user staff 64 Jan 10 11:00 projects")
        let plainFile = classify(longEntry: "-rw-r--r-- 1 user staff 1024 Jan 10 11:00 notes.txt")

        XCTAssertEqual(windowsDir, 1)
        XCTAssertEqual(posixDir, 1)
        XCTAssertEqual(plainFile, 0)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func classify(longEntry: String) -> Int32 {
        longEntry.withCString { pointer in
            macfusegui_libssh2_classify_directory_entry(0, 0, pointer)
        }
    }
}
