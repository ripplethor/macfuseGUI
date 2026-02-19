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
final class ValidationServiceTests: XCTestCase {
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func testValidationRejectsInvalidFields() throws {
        let service = ValidationService()
        let invalid = RemoteDraft(
            displayName: "",
            host: "bad host with spaces",
            port: 70000,
            username: "",
            authMode: .privateKey,
            privateKeyPath: "/does/not/exist",
            password: "",
            remoteDirectory: "relative/path",
            localMountPoint: "/does/not/exist"
        )

        let errors = service.validateDraft(invalid, hasStoredPassword: false)
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains(where: { $0.contains("Display name") }))
        XCTAssertTrue(errors.contains(where: { $0.contains("Host/IP") }))
        XCTAssertTrue(errors.contains(where: { $0.contains("Port") }))
        XCTAssertTrue(errors.contains(where: { $0.contains("Remote directory") }))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func testValidationAllowsPasswordModeWithStoredPassword() throws {
        let tmp = FileManager.default.temporaryDirectory
        let mountPath = tmp.path

        let draft = RemoteDraft(
            displayName: "Server",
            host: "example.com",
            port: 22,
            username: "dev",
            authMode: .password,
            privateKeyPath: "",
            password: "",
            remoteDirectory: "/home/dev",
            localMountPoint: mountPath
        )

        let service = ValidationService()
        let errors = service.validateDraft(draft, hasStoredPassword: true)
        XCTAssertTrue(errors.isEmpty)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testValidationAllowsWindowsStyleRemotePath() {
        let draft = RemoteDraft(
            displayName: "Windows Host",
            host: "win-host.local",
            port: 22,
            username: "dev",
            authMode: .password,
            privateKeyPath: "",
            password: "",
            remoteDirectory: "C:/Users/dev",
            localMountPoint: FileManager.default.temporaryDirectory.path
        )

        let service = ValidationService()
        let errors = service.validateDraft(draft, hasStoredPassword: true)
        XCTAssertTrue(errors.isEmpty)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecoveryBackoffIsAggressiveAfterWakeForTransientFailure() {
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 0,
                trigger: "wake",
                lastError: "Connection reset by peer"
            ),
            0
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 1,
                trigger: "wake",
                lastError: "Connection reset by peer"
            ),
            1
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 4,
                trigger: "wake",
                lastError: "Connection reset by peer"
            ),
            8
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecoveryBackoffIsConservativeForPeriodicNonTransientFailure() {
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 0,
                trigger: "periodic",
                lastError: "sshfs reported success, but mount was not detected."
            ),
            0
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 1,
                trigger: "periodic",
                lastError: "sshfs reported success, but mount was not detected."
            ),
            2
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 2,
                trigger: "periodic",
                lastError: "sshfs reported success, but mount was not detected."
            ),
            5
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecoveryTransientFailureClassifier() {
        XCTAssertTrue(RemotesViewModel.isTransientReconnectFailureMessage("broken pipe"))
        XCTAssertTrue(RemotesViewModel.isTransientReconnectFailureMessage("operation timed out"))
        XCTAssertFalse(RemotesViewModel.isTransientReconnectFailureMessage("authentication failed"))
        XCTAssertFalse(RemotesViewModel.isTransientReconnectFailureMessage(nil))
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecoveryBackoffCapsAtOneMinute() {
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 999,
                trigger: "periodic",
                lastError: "network is unreachable"
            ),
            60
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 999,
                trigger: "wake",
                lastError: "connection reset"
            ),
            60
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRequiredRecoveryStrikesByTriggerType() {
        XCTAssertEqual(RemotesViewModel.requiredRecoveryStrikes(for: "wake"), 1)
        XCTAssertEqual(RemotesViewModel.requiredRecoveryStrikes(for: "network-restored"), 1)
        XCTAssertEqual(RemotesViewModel.requiredRecoveryStrikes(for: "periodic"), 2)
        XCTAssertEqual(RemotesViewModel.requiredRecoveryStrikes(for: "status-change"), 1)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testNetworkRestoredBackoffStartsFastForTransientFailures() {
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 0,
                trigger: "network-restored",
                lastError: "broken pipe"
            ),
            0
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 1,
                trigger: "network-restored",
                lastError: "broken pipe"
            ),
            1
        )
        XCTAssertEqual(
            RemotesViewModel.reconnectDelaySeconds(
                attempt: 2,
                trigger: "network-restored",
                lastError: "broken pipe"
            ),
            2
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testRecoveryBurstDelaysForWakeAndNetworkRestore() {
        XCTAssertEqual(RemotesViewModel.recoveryBurstDelays(for: "wake"), [0, 1, 3, 8])
        XCTAssertEqual(RemotesViewModel.recoveryBurstDelays(for: "network-restored"), [0, 2, 6])
        XCTAssertEqual(RemotesViewModel.recoveryBurstDelays(for: "periodic"), [0])
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testNetworkReachabilityTransitionMapping() {
        XCTAssertEqual(
            RemotesViewModel.networkReachabilityTransition(previousReachable: false, currentReachable: false),
            .unchanged
        )
        XCTAssertEqual(
            RemotesViewModel.networkReachabilityTransition(previousReachable: false, currentReachable: true),
            .becameReachable
        )
        XCTAssertEqual(
            RemotesViewModel.networkReachabilityTransition(previousReachable: true, currentReachable: false),
            .becameUnreachable
        )
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func testWatchdogTimeoutMessageSelection() {
        XCTAssertEqual(
            RemotesViewModel.watchdogTimeoutMessage(
                intent: .connect,
                currentState: .connecting,
                disconnectWatchdogTimeout: 10
            ),
            "Connect timed out. Check network/credentials and retry."
        )
        XCTAssertNil(
            RemotesViewModel.watchdogTimeoutMessage(
                intent: .connect,
                currentState: .connected,
                disconnectWatchdogTimeout: 10
            )
        )
        XCTAssertEqual(
            RemotesViewModel.watchdogTimeoutMessage(
                intent: .disconnect,
                currentState: .disconnecting,
                disconnectWatchdogTimeout: 12
            ),
            "Disconnect timed out after 12s. Close files using the mount, then retry."
        )
        XCTAssertEqual(
            RemotesViewModel.watchdogTimeoutMessage(
                intent: .refresh,
                currentState: .connected,
                disconnectWatchdogTimeout: 10
            ),
            "Status refresh timed out. Try Refresh again."
        )
    }
}
