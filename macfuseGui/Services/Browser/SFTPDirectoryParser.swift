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
struct SFTPListParseResult: Sendable {
    var resolvedPath: String?
    var entries: [RemoteDirectoryItem]
}

/// Beginner note: This type groups related state and behavior for one part of the app.
/// Read stored properties first, then follow methods top-to-bottom to understand flow.
enum SFTPDirectoryParser {
    static func parse(output: String, basePath: String) -> SFTPListParseResult {
        let resolvedPath = parseWorkingDirectory(from: output).map { BrowserPathNormalizer.normalize(path: $0) }
        let effectiveBase = resolvedPath ?? BrowserPathNormalizer.normalize(path: basePath)

        var items: [RemoteDirectoryItem] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            if line.first == "d" {
                let columns = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
                guard columns.count >= 9 else { continue }
                let name = String(columns[8]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard name != ".", name != "..", !name.isEmpty else { continue }
                items.append(
                    RemoteDirectoryItem(
                        name: name,
                        fullPath: BrowserPathNormalizer.join(base: effectiveBase, child: name),
                        isDirectory: true,
                        modifiedAt: parseUNIXTimestamp(columns: columns),
                        sizeBytes: nil
                    )
                )
                continue
            }

            if line.localizedCaseInsensitiveContains("<DIR>") {
                let columns = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
                guard let dirIndex = columns.firstIndex(where: { String($0).caseInsensitiveCompare("<DIR>") == .orderedSame }),
                      dirIndex + 1 < columns.count else { continue }
                let name = columns[(dirIndex + 1)...].map(String.init).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                guard name != ".", name != "..", !name.isEmpty else { continue }
                items.append(
                    RemoteDirectoryItem(
                        name: name,
                        fullPath: BrowserPathNormalizer.join(base: effectiveBase, child: name),
                        isDirectory: true,
                        modifiedAt: parseWindowsTimestamp(from: line),
                        sizeBytes: nil
                    )
                )
            }
        }

        let deduped = deduplicate(items: items)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return SFTPListParseResult(resolvedPath: resolvedPath, entries: deduped)
    }

    private static func parseWorkingDirectory(from output: String) -> String? {
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.localizedCaseInsensitiveContains("remote working directory:") {
                guard let range = line.range(of: ":") else { continue }
                let candidate = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }
        return nil
    }

    private static func deduplicate(items: [RemoteDirectoryItem]) -> [RemoteDirectoryItem] {
        var seen: Set<String> = []
        var output: [RemoteDirectoryItem] = []
        for item in items {
            let key = item.fullPath.lowercased()
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            output.append(item)
        }
        return output
    }

    private static func parseUNIXTimestamp(columns: [Substring]) -> Date? {
        guard columns.count >= 8 else {
            return nil
        }
        let month = String(columns[5])
        let day = String(columns[6])
        let yearOrTime = String(columns[7])
        let token = "\(month) \(day) \(yearOrTime)"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        if yearOrTime.contains(":") {
            formatter.dateFormat = "MMM d HH:mm"
        } else {
            formatter.dateFormat = "MMM d yyyy"
        }
        return formatter.date(from: token)
    }

    private static func parseWindowsTimestamp(from line: String) -> Date? {
        // Example: 07/18/2025  10:21 AM    <DIR>  Documents
        let parts = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard parts.count >= 3 else {
            return nil
        }
        let stamp = "\(parts[0]) \(parts[1]) \(parts[2])"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy hh:mm a"
        return formatter.date(from: stamp)
    }
}
