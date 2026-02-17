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
final class ValidationService {
    private let fileManager: FileManager

    /// Beginner note: Initializers create valid state before any other method is used.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func validateDraft(
        _ draft: RemoteDraft,
        hasStoredPassword: Bool
    ) -> [String] {
        var errors: [String] = []

        let displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty {
            errors.append("Display name is required.")
        }

        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty {
            errors.append("Host/IP is required.")
        } else {
            if !isSupportedHost(host) {
                errors.append("Host/IP contains unsupported characters.")
            } else if containsUnsafeControlCharacters(host) {
                errors.append("Host/IP contains invalid control characters.")
            }
        }

        if !(1...65535).contains(draft.port) {
            errors.append("Port must be between 1 and 65535.")
        }

        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty {
            errors.append("Username is required.")
        } else if username.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            errors.append("Username cannot contain whitespace characters.")
        }

        let remoteDirectory = draft.remoteDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isSupportedRemotePath(remoteDirectory) {
            errors.append("Remote directory must be absolute (for example /home/user or C:/Users/User).")
        } else if containsUnsafeControlCharacters(remoteDirectory) {
            errors.append("Remote directory contains invalid control characters.")
        }

        let localMount = draft.localMountPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if localMount.isEmpty {
            errors.append("Local mount point is required.")
        } else if !localMount.hasPrefix("/") {
            errors.append("Local mount point must be an absolute path.")
        } else if containsUnsafeControlCharacters(localMount) {
            errors.append("Local mount point contains invalid control characters.")
        } else {
            let normalizedMount = URL(fileURLWithPath: localMount).standardizedFileURL.path
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: normalizedMount, isDirectory: &isDir) {
                if !isDir.boolValue {
                    errors.append("Local mount point must be a directory.")
                }
            } else {
                let parentPath = URL(fileURLWithPath: normalizedMount).deletingLastPathComponent().path
                var parentIsDir: ObjCBool = false
                if !fileManager.fileExists(atPath: parentPath, isDirectory: &parentIsDir) || !parentIsDir.boolValue {
                    errors.append("Parent folder for local mount point must exist.")
                } else if !fileManager.isWritableFile(atPath: parentPath) {
                    errors.append("Parent folder for local mount point is not writable.")
                }
            }
        }

        switch draft.authMode {
        case .privateKey:
            let keyPath = draft.privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if keyPath.isEmpty {
                errors.append("Private key path is required for key authentication.")
            } else if !keyPath.hasPrefix("/") {
                errors.append("Private key path must be an absolute path.")
            } else if containsUnsafeControlCharacters(keyPath) {
                errors.append("Private key path contains invalid control characters.")
            } else {
                var isDir: ObjCBool = false
                if !fileManager.fileExists(atPath: keyPath, isDirectory: &isDir) || isDir.boolValue {
                    errors.append("Private key file does not exist.")
                }
                if !fileManager.isReadableFile(atPath: keyPath) {
                    errors.append("Private key file is not readable.")
                }
            }
        case .password:
            if !hasStoredPassword && draft.password.isEmpty {
                errors.append("Password is required for password authentication.")
            }
        }

        return errors
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func containsUnsafeControlCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func isSupportedRemotePath(_ value: String) -> Bool {
        if value.hasPrefix("/") || value.hasPrefix("~") {
            return true
        }

        return isWindowsDrivePath(value)
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func isSupportedHost(_ value: String) -> Bool {
        let allowedScalars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:-")
        return value.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func isWindowsDrivePath(_ value: String) -> Bool {
        guard value.count >= 3 else {
            return false
        }

        let chars = Array(value)
        return chars[0].isLetter
            && chars[1] == ":"
            && (chars[2] == "/" || chars[2] == "\\")
    }
}
