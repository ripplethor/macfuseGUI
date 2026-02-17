// BEGINNER FILE GUIDE
// Layer: Core service layer
// Purpose: This file performs non-UI work such as mount commands, process execution, validation, persistence, or diagnostics.
// Called by: Called by view models to execute user actions and background recovery work.
// Calls into: May call system APIs, external tools, Keychain, filesystem, and helper services.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
struct AskpassContext {
    let scriptURL: URL
    let environment: [String: String]
    let secretValues: [String]
    let cleanup: () -> Void
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
final class AskpassHelper {
    private let fileManager: FileManager

    /// Beginner note: Initializers create valid state before any other method is used.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    /// This can throw an error: callers should use do/try/catch or propagate the error.
    func makeContext(password: String) throws -> AskpassContext {
        let tmpDir = fileManager.temporaryDirectory.appendingPathComponent("macfusegui-askpass-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: tmpDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let variableName = "MACFUSEGUI_ASKPASS_PASSWORD_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let scriptURL = tmpDir.appendingPathComponent("askpass.sh", isDirectory: false)

        let script = """
        #!/bin/sh
        printf "%s\\n" "${\(variableName)}"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let environment: [String: String] = [
            "SSH_ASKPASS": scriptURL.path,
            "SSH_ASKPASS_REQUIRE": "force",
            "DISPLAY": "1",
            variableName: password
        ]

        let fileManager = self.fileManager

        return AskpassContext(
            scriptURL: scriptURL,
            environment: environment,
            secretValues: [password],
            cleanup: {
                try? fileManager.removeItem(at: tmpDir)
            }
        )
    }
}
