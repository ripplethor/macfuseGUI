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
    private static func collapseRepeatedSlashes(_ value: String) -> String {
        value.replacingOccurrences(of: "/{2,}", with: "/", options: .regularExpression)
    }

    static func normalize(path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return "/"
        }

        normalized = normalized.replacingOccurrences(of: "\\", with: "/")
        normalized = collapseRepeatedSlashes(normalized)

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

        // Run a second pass after adding a leading slash so values like "/D::"
        // and "/D::/wwwroot" are canonicalized to "/D:/" and "/D:/wwwroot".
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
            return normalized
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

        if normalizedChild.isEmpty {
            return normalizedBase
        }

        let childForChecks = normalizedChild.replacingOccurrences(of: "\\", with: "/")
        // Absolute child paths replace the base path, matching POSIX join semantics.
        if childForChecks.hasPrefix("/")
            || childForChecks == "~"
            || childForChecks.hasPrefix("~/")
            || isWindowsDrivePath(childForChecks) {
            return normalize(path: childForChecks)
        }

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
        // The list is intentionally speculative so browser root navigation still
        // works across both UNIX-like and Windows OpenSSH servers.
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
        let first = trimmed[trimmed.startIndex]
        let second = trimmed[trimmed.index(after: trimmed.startIndex)]
        return first.isLetter && second == ":"
    }

    private static func isWindowsDrivePath(_ value: String) -> Bool {
        guard value.count >= 2 else {
            return false
        }

        let start = value.startIndex
        let secondIndex = value.index(after: start)
        let first = value[start]
        let second = value[secondIndex]
        guard first.isLetter, second == ":" else {
            return false
        }

        guard value.count >= 3 else {
            return true
        }

        let third = value[value.index(start, offsetBy: 2)]
        return third == "/" || third == "\\"
    }

    private static func normalizeWindowsDriveArtifacts(_ original: String) -> String {
        guard !original.isEmpty else {
            return original
        }

        var working = original
        let hadLeadingSlash = working.hasPrefix("/")
        if hadLeadingSlash {
            working.removeFirst()
        }

        // Return the original value. `working` may have had a leading slash removed.
        guard working.count >= 2 else {
            return original
        }

        let start = working.startIndex
        let secondIndex = working.index(after: start)
        let driveLetter = working[start]
        let driveSeparator = working[secondIndex]
        guard driveLetter.isLetter, driveSeparator == ":" else {
            return original
        }

        var tail = String(working.dropFirst(2))
        while tail.hasPrefix(":") {
            tail.removeFirst()
        }

        tail = collapseRepeatedSlashes(tail)

        if tail.isEmpty {
            tail = "/"
        }

        if !tail.isEmpty && !tail.hasPrefix("/") {
            tail = "/\(tail)"
        }

        let rebuilt = "\(driveLetter):\(tail)"
        return hadLeadingSlash ? "/\(rebuilt)" : rebuilt
    }

    private static func isWindowsDriveRootPath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4 else {
            return false
        }
        let start = trimmed.startIndex
        let second = trimmed.index(after: start)
        let third = trimmed.index(after: second)
        let fourth = trimmed.index(after: third)
        return trimmed[start] == "/"
            && trimmed[second].isLetter
            && trimmed[third] == ":"
            && trimmed[fourth] == "/"
    }
}
