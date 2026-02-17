// BEGINNER FILE GUIDE
// Layer: Browser service layer
// Purpose: This file implements remote directory browsing sessions, transport, parsing, or path normalization.
// Called by: Called from RemoteDirectoryBrowserService and browser-facing view models.
// Calls into: Calls into libssh2 bridge, diagnostics, and browser state models.
// Concurrency: Runs with standard synchronous execution unless specific methods use async/await.
// Maintenance tip: Start reading top-to-bottom once, then follow one user action end-to-end through call sites.

import Foundation

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum BrowserPathNormalizer {
    static func normalize(path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return "/"
        }

        normalized = normalized.replacingOccurrences(of: "\\", with: "/")
        while normalized.contains("//") {
            normalized = normalized.replacingOccurrences(of: "//", with: "/")
        }

        normalized = normalizeWindowsDriveArtifacts(normalized)

        if normalized == "." {
            return "/"
        }
        if normalized == "~" {
            return "~"
        }

        if isWindowsDrivePath(normalized), !normalized.hasPrefix("/") {
            normalized = "/\(normalized)"
        }

        normalized = normalizeWindowsDriveArtifacts(normalized)

        if normalized.hasPrefix("~/") {
            while normalized.count > 2 && normalized.hasSuffix("/") {
                normalized.removeLast()
            }
            return normalized
        }

        if !normalized.hasPrefix("/") {
            normalized = "/\(normalized)"
        }

        if isWindowsDriveRootPath(normalized) {
            return normalized
        }

        while normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return normalized
    }

    static func parentPath(of path: String) -> String {
        let normalized = normalize(path: path)

        if normalized == "/" || normalized == "~" {
            return normalized == "~" ? "~" : "/"
        }

        if normalized.hasPrefix("~/") {
            let tail = String(normalized.dropFirst(2))
            let components = tail.split(separator: "/", omittingEmptySubsequences: true)
            if components.count <= 1 {
                return "~"
            }
            return "~/" + components.dropLast().joined(separator: "/")
        }

        if normalized.hasPrefix("/") {
            let components = normalized
                .dropFirst()
                .split(separator: "/", omittingEmptySubsequences: true)
            if components.count <= 1 {
                return "/"
            }
            return normalize(path: "/" + components.dropLast().joined(separator: "/"))
        }

        let components = normalized.split(separator: "/", omittingEmptySubsequences: true)
        if components.count <= 1 {
            return "/"
        }
        return normalize(path: "/" + components.dropLast().joined(separator: "/"))
    }

    static func join(base: String, child: String) -> String {
        let normalizedBase = normalize(path: base)
        let normalizedChild = child.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedBase == "/" {
            return normalize(path: "/\(normalizedChild)")
        }
        if normalizedBase == "~" {
            return normalize(path: "~/\(normalizedChild)")
        }

        let trimmedBase = normalizedBase.hasSuffix("/") ? String(normalizedBase.dropLast()) : normalizedBase
        return normalize(path: "\(trimmedBase)/\(normalizedChild)")
    }

    static func rootCandidates(for username: String) -> [String] {
        let fallback = ["/", "/C:/", "/D:/", "/C:/Users/\(username)", "~"]
        var seen: Set<String> = []
        var ordered: [String] = []
        for value in fallback {
            let normalized = normalize(path: value)
            let key = normalized.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(normalized)
            }
        }
        return ordered
    }

    static func isWindowsDriveComponent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 2 else {
            return false
        }
        let chars = Array(trimmed)
        return chars[0].isLetter && chars[1] == ":"
    }

    private static func isWindowsDrivePath(_ value: String) -> Bool {
        guard value.count >= 2 else {
            return false
        }

        let chars = Array(value)
        guard chars[0].isLetter, chars[1] == ":" else {
            return false
        }

        guard chars.count >= 3 else {
            return true
        }

        return chars[2] == "/" || chars[2] == "\\" || chars[2] == ":"
    }

    private static func normalizeWindowsDriveArtifacts(_ value: String) -> String {
        guard !value.isEmpty else {
            return value
        }

        var working = value
        let hadLeadingSlash = working.hasPrefix("/")
        if hadLeadingSlash {
            working.removeFirst()
        }

        guard working.count >= 2 else {
            return value
        }

        let chars = Array(working)
        guard chars[0].isLetter, chars[1] == ":" else {
            return value
        }

        var tail = String(working.dropFirst(2))
        while tail.hasPrefix(":") {
            tail.removeFirst()
        }

        while tail.contains("//") {
            tail = tail.replacingOccurrences(of: "//", with: "/")
        }

        if tail.isEmpty {
            tail = "/"
        }

        if !tail.isEmpty && !tail.hasPrefix("/") {
            tail = "/\(tail)"
        }

        let rebuilt = "\(chars[0]):\(tail)"
        return hadLeadingSlash ? "/\(rebuilt)" : rebuilt
    }

    private static func isWindowsDriveRootPath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4 else {
            return false
        }
        let chars = Array(trimmed)
        return chars[0] == "/" && chars[1].isLetter && chars[2] == ":" && chars[3] == "/"
    }
}
