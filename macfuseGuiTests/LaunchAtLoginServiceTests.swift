// BEGINNER FILE GUIDE
// Layer: Automated test layer
// Purpose: This file verifies production behavior and protects against regressions when code changes.
// Called by: Executed by XCTest during xcodebuild test or IDE test runs.
// Calls into: Calls production code and test fixtures with deterministic assertions.
// Concurrency: Runs on MainActor for UI-safe state updates; this means logic is serialized on the main actor context.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation
import ServiceManagement
import XCTest
@testable import macfuseGui

@MainActor
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class LaunchAtLoginServiceTests: XCTestCase {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func testCurrentStateRequiresApprovalWhenServiceRequiresApprovalAndNoFallback() throws {
        let context = try makeContext()
        defer { try? context.cleanup() }

        let service = LaunchAtLoginService(
            appService: FakeLaunchAtLoginAppService(status: .requiresApproval),
            fileManager: context.fileManager,
            runner: FakeLaunchctlRunner()
        )

        let state = service.currentState()
        XCTAssertFalse(state.enabled)
        XCTAssertTrue(state.requiresApproval)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async and throwing: callers must await it and handle failures.
    func testSetEnabledFallsBackToLaunchAgentWhenAppServiceRegisterFails() async throws {
        let context = try makeContext()
        defer { try? context.cleanup() }

        let appService = FakeLaunchAtLoginAppService(
            status: .notRegistered,
            registerError: AppError.unknown("register failed")
        )
        let runner = FakeLaunchctlRunner()
        let service = LaunchAtLoginService(
            appService: appService,
            fileManager: context.fileManager,
            runner: runner
        )

        let state = try await service.setEnabled(true)
        XCTAssertTrue(state.enabled)
        XCTAssertEqual(state.detail, "Enabled via LaunchAgent fallback.")
        XCTAssertTrue(context.fileManager.fileExists(atPath: context.launchAgentPlistURL.path))
        let didBootstrap = await runner.hasLaunchctlSubcommand("bootstrap")
        let didEnable = await runner.hasLaunchctlSubcommand("enable")
        XCTAssertTrue(didBootstrap)
        XCTAssertTrue(didEnable)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async and throwing: callers must await it and handle failures.
    func testSetDisabledRemovesFallbackPlistEvenWhenUnregisterFails() async throws {
        let context = try makeContext()
        defer { try? context.cleanup() }

        try context.fileManager.createDirectory(
            at: context.launchAgentPlistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "<plist/>".write(to: context.launchAgentPlistURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(context.fileManager.fileExists(atPath: context.launchAgentPlistURL.path))

        let appService = FakeLaunchAtLoginAppService(
            status: .notRegistered,
            unregisterError: AppError.unknown("unregister failed")
        )
        let runner = FakeLaunchctlRunner()
        let service = LaunchAtLoginService(
            appService: appService,
            fileManager: context.fileManager,
            runner: runner
        )

        let state = try await service.setEnabled(false)
        XCTAssertFalse(state.enabled)
        XCTAssertFalse(context.fileManager.fileExists(atPath: context.launchAgentPlistURL.path))
        let didDisable = await runner.hasLaunchctlSubcommand("disable")
        XCTAssertTrue(didDisable)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func makeContext() throws -> LaunchAtLoginTestContext {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macfusegui-launch-tests-\(UUID().uuidString)", isDirectory: true)
        let homeURL = rootURL.appendingPathComponent("home", isDirectory: true)
        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)

        let fileManager = TestHomeFileManager(homeDirectoryURL: homeURL)
        let launchAgentPlistURL = homeURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("com.visualweb.macfusegui.launchagent.plist")

        return LaunchAtLoginTestContext(
            fileManager: fileManager,
            rootURL: rootURL,
            launchAgentPlistURL: launchAgentPlistURL
        )
    }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
private struct LaunchAtLoginTestContext {
    let fileManager: TestHomeFileManager
    let rootURL: URL
    let launchAgentPlistURL: URL

    func cleanup() throws {
        if FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
    }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
private final class TestHomeFileManager: FileManager {
    private let testHomeDirectoryURL: URL

    init(homeDirectoryURL: URL) {
        self.testHomeDirectoryURL = homeDirectoryURL
        super.init()
    }

    override var homeDirectoryForCurrentUser: URL {
        testHomeDirectoryURL
    }
}

@MainActor
/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
private final class FakeLaunchAtLoginAppService: LaunchAtLoginAppService {
    var status: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?

    init(
        status: SMAppService.Status,
        registerError: Error? = nil,
        unregisterError: Error? = nil
    ) {
        self.status = status
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        if let registerError {
            throw registerError
        }
    }

    func unregister() async throws {
        if let unregisterError {
            throw unregisterError
        }
    }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
private actor FakeLaunchctlRunner: ProcessRunning {
    private var subcommands: [String] = []

    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
        standardInput: String?
    ) async throws -> ProcessResult {
        if executable == "/bin/launchctl", let subcommand = arguments.first {
            subcommands.append(subcommand)
        }

        return ProcessResult(
            executable: executable,
            arguments: arguments,
            stdout: "",
            stderr: "",
            exitCode: 0,
            timedOut: false,
            duration: 0.01
        )
    }

    func hasLaunchctlSubcommand(_ name: String) -> Bool {
        subcommands.contains(name)
    }
}
