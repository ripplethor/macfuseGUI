// BEGINNER FILE GUIDE
// Layer: Core service layer
// Purpose: This file performs non-UI work such as mount commands, process execution, validation, persistence, or diagnostics.
// Called by: Called by view models to execute user actions and background recovery work.
// Calls into: May call system APIs, external tools, Keychain, filesystem, and helper services.
// Concurrency: Contains async functions; these can suspend and resume without blocking the calling thread.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation
import Darwin

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct ProcessResult: Sendable {
    let executable: String
    let arguments: [String]
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let timedOut: Bool
    let duration: TimeInterval
}

/// Beginner note: This protocol defines the minimum process execution behavior used by services.
/// Using a protocol lets tests inject a fake runner without launching real system processes.
protocol ProcessRunning {
    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This is async and throwing: callers must await it and handle failures.
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
        standardInput: String?
    ) async throws -> ProcessResult
}

extension ProcessRunning {
    /// Beginner note: This overload keeps call sites concise by providing common defaults.
    /// Implementers still only need to implement the full method signature above.
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval = 30,
        standardInput: String? = nil
    ) async throws -> ProcessResult {
        try await run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            standardInput: standardInput
        )
    }
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
// @unchecked Sendable is safe here because all mutable shared state is behind processRegistryLock.
final class ProcessRunner: ProcessRunning, @unchecked Sendable {
    private struct ProcessHandle {
        let pid: Int32
        let processGroupID: Int32?
    }

    private let processRegistryLock = NSLock()
    private var runningPIDs: [UUID: ProcessHandle] = [:]
    private var pendingCancellations: Set<UUID> = []

    /// Beginner note: This method is one step in the feature workflow for this file.
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval = 30,
        standardInput: String? = nil
    ) async throws -> ProcessResult {
        let commandID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let start = Date()
                        let process = Process()
                        let stdoutPipe = Pipe()
                        let stderrPipe = Pipe()
                        let stdinPipe = Pipe()
                        process.executableURL = URL(fileURLWithPath: executable)
                        process.arguments = arguments
                        var mergedEnvironment = ProcessInfo.processInfo.environment
                        environment.forEach { mergedEnvironment[$0.key] = $0.value }
                        process.environment = mergedEnvironment
                        process.standardOutput = stdoutPipe
                        process.standardError = stderrPipe
                        if standardInput != nil {
                            process.standardInput = stdinPipe
                        }

                        var didTimeout = false
                        let terminationSemaphore = DispatchSemaphore(value: 0)

                        var stdoutData = Data()
                        var stderrData = Data()
                        let captureLock = NSLock()
                        var captureActive = true
                        var drained = false

                        /// Beginner note: This method is one step in the feature workflow for this file.
                        func appendOutput(_ chunk: Data, toStdout: Bool) {
                            guard !chunk.isEmpty else { return }
                            captureLock.lock()
                            defer { captureLock.unlock() }
                            guard captureActive else { return }
                            if toStdout {
                                stdoutData.append(chunk)
                            } else {
                                stderrData.append(chunk)
                            }
                        }

                        /// Beginner note: This method is one step in the feature workflow for this file.
                        func stopCaptureHandlers() {
                            captureLock.lock()
                            if !captureActive {
                                captureLock.unlock()
                                return
                            }
                            captureActive = false
                            captureLock.unlock()

                            stdoutPipe.fileHandleForReading.readabilityHandler = nil
                            stderrPipe.fileHandleForReading.readabilityHandler = nil
                        }

                        /// Beginner note: This method is one step in the feature workflow for this file.
                        func drainRemainingOutputOnce() {
                            captureLock.lock()
                            if drained {
                                captureLock.unlock()
                                return
                            }
                            drained = true
                            captureLock.unlock()

                            let stdoutTail = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                            let stderrTail = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                            captureLock.lock()
                            stdoutData.append(stdoutTail)
                            stderrData.append(stderrTail)
                            captureLock.unlock()
                        }

                        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                            let chunk = handle.availableData
                            appendOutput(chunk, toStdout: true)
                        }

                        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                            let chunk = handle.availableData
                            appendOutput(chunk, toStdout: false)
                        }

                        process.terminationHandler = { _ in
                            terminationSemaphore.signal()
                        }

                        try process.run()
                        let pid = process.processIdentifier
                        var processGroupID: Int32?
                        if setpgid(pid, pid) == 0 {
                            processGroupID = pid
                        }
                        self.registerRunningProcess(
                            commandID: commandID,
                            pid: pid,
                            processGroupID: processGroupID
                        )

                        if let standardInput, let inputData = standardInput.data(using: .utf8) {
                            stdinPipe.fileHandleForWriting.write(inputData)
                            try? stdinPipe.fileHandleForWriting.close()
                        }

                        let waitResult = terminationSemaphore.wait(timeout: .now() + timeout)
                        if waitResult == .timedOut {
                            didTimeout = true

                            // Stop handlers before termination to avoid late appends during shutdown.
                            stopCaptureHandlers()

                            if process.isRunning {
                                if let processGroupID, processGroupID > 1 {
                                    _ = kill(-processGroupID, SIGTERM)
                                }
                                process.terminate()
                            }

                            // Keep timeout teardown short so caller-level watchdog budgets stay meaningful.
                            let graceResult = terminationSemaphore.wait(timeout: .now() + 0.6)
                            if graceResult == .timedOut, process.isRunning {
                                if let processGroupID, processGroupID > 1 {
                                    _ = kill(-processGroupID, SIGKILL)
                                }
                                _ = kill(process.processIdentifier, SIGKILL)
                                _ = terminationSemaphore.wait(timeout: .now() + 0.6)
                            }
                        }

                        stopCaptureHandlers()

                        if !process.isRunning {
                            drainRemainingOutputOnce()
                        }

                        captureLock.lock()
                        let finalStdout = stdoutData
                        let finalStderr = stderrData
                        captureLock.unlock()

                        let stdout = String(data: finalStdout, encoding: .utf8) ?? ""
                        let stderr = String(data: finalStderr, encoding: .utf8) ?? ""
                        let stillRunning = process.isRunning

                        let result = ProcessResult(
                            executable: executable,
                            arguments: arguments,
                            stdout: stdout,
                            stderr: stderr,
                            exitCode: stillRunning ? -1 : process.terminationStatus,
                            timedOut: didTimeout || stillRunning,
                            duration: Date().timeIntervalSince(start)
                        )
                        self.unregisterRunningProcess(commandID: commandID)
                        continuation.resume(returning: result)
                    } catch {
                        self.unregisterRunningProcess(commandID: commandID)
                        continuation.resume(throwing: AppError.processFailure("Failed to start process: \(error.localizedDescription)"))
                    }
                }
            }
        } onCancel: {
            self.cancelRunningProcess(commandID: commandID)
        }
    }

    private func registerRunningProcess(commandID: UUID, pid: Int32, processGroupID: Int32?) {
        processRegistryLock.lock()
        runningPIDs[commandID] = ProcessHandle(pid: pid, processGroupID: processGroupID)
        let cancelImmediately = pendingCancellations.remove(commandID) != nil
        processRegistryLock.unlock()

        if cancelImmediately {
            terminateProcess(ProcessHandle(pid: pid, processGroupID: processGroupID))
        }
    }

    private func unregisterRunningProcess(commandID: UUID) {
        processRegistryLock.lock()
        runningPIDs.removeValue(forKey: commandID)
        pendingCancellations.remove(commandID)
        processRegistryLock.unlock()
    }

    private func cancelRunningProcess(commandID: UUID) {
        processRegistryLock.lock()
        if let processHandle = runningPIDs[commandID] {
            processRegistryLock.unlock()
            terminateProcess(processHandle)
            return
        }
        pendingCancellations.insert(commandID)
        processRegistryLock.unlock()
    }

    private func terminateProcess(_ handle: ProcessHandle) {
        guard handle.pid > 1 else {
            return
        }
        if let processGroupID = handle.processGroupID, processGroupID > 1 {
            _ = kill(-processGroupID, SIGTERM)
        }
        _ = kill(handle.pid, SIGTERM)
        // By design this is a short blocking grace period in a termination-only path.
        // It gives child processes a chance to exit cleanly before escalating to SIGKILL.
        usleep(250_000)
        if let processGroupID = handle.processGroupID, processGroupID > 1 {
            _ = kill(-processGroupID, SIGKILL)
        }
        _ = kill(handle.pid, SIGKILL)
    }
}
