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
    private enum ListingFormat {
        case unix
        case windows
    }

    // Remote server timezone is not provided by these listing formats.
    // Parse in UTC for stable, deterministic timestamps across clients.
    private static let parserTimeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
    private static let parserLocale = Locale(identifier: "en_US_POSIX")
    private static let timestampFormatterLock = NSLock()

    private static let unixDateFormatter: DateFormatter = makeFormatter("MMM d yyyy")
    private static let unixDateTimeFormatter: DateFormatter = makeFormatter("MMM d yyyy HH:mm")
    private static let windows12HourFormatters: [DateFormatter] = [
        makeFormatter("MM/dd/yyyy hh:mm a"),
        makeFormatter("M/d/yyyy hh:mm a"),
        makeFormatter("dd/MM/yyyy hh:mm a"),
        makeFormatter("d/M/yyyy hh:mm a")
    ]
    private static let windows24HourFormatters: [DateFormatter] = [
        makeFormatter("MM/dd/yyyy HH:mm"),
        makeFormatter("M/d/yyyy HH:mm"),
        makeFormatter("dd/MM/yyyy HH:mm"),
        makeFormatter("d/M/yyyy HH:mm")
    ]

    static func parse(output: String, basePath: String) -> SFTPListParseResult {
        let resolvedPath = parseWorkingDirectory(from: output).map { BrowserPathNormalizer.normalize(path: $0) }
        let effectiveBase = resolvedPath ?? BrowserPathNormalizer.normalize(path: basePath)
        let listingFormat = detectListingFormat(from: output)

        var items: [RemoteDirectoryItem] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            switch listingFormat {
            case .unix:
                if let item = parseUNIXDirectoryLine(line, basePath: effectiveBase) {
                    items.append(item)
                }
            case .windows:
                if let item = parseWindowsDirectoryLine(line, basePath: effectiveBase) {
                    items.append(item)
                }
            }
        }

        let deduped = deduplicate(items: items)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return SFTPListParseResult(resolvedPath: resolvedPath, entries: deduped)
    }

    private static func parseWorkingDirectory(from output: String) -> String? {
        // Interactive sftp output can contain multiple path echoes; use the latest one.
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
            let key = item.fullPath
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            output.append(item)
        }
        return output
    }

    private static func detectListingFormat(from output: String) -> ListingFormat {
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if isLikelyWindowsDirectoryLine(line) {
                return .windows
            }
        }
        return .unix
    }

    private static func parseUNIXDirectoryLine(_ line: String, basePath: String) -> RemoteDirectoryItem? {
        guard line.first == "d" else {
            return nil
        }

        let columns = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
        guard columns.count >= 9 else {
            return nil
        }

        let name = String(columns[8]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard name != ".", name != "..", !name.isEmpty else {
            return nil
        }

        return RemoteDirectoryItem(
            name: name,
            fullPath: BrowserPathNormalizer.join(base: basePath, child: name),
            isDirectory: true,
            modifiedAt: parseUNIXTimestamp(columns: columns),
            sizeBytes: nil
        )
    }

    private static func parseWindowsDirectoryLine(_ line: String, basePath: String) -> RemoteDirectoryItem? {
        let columns = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard let dirIndex = columns.firstIndex(where: { String($0).caseInsensitiveCompare("<DIR>") == .orderedSame }),
              dirIndex + 1 < columns.count else {
            return nil
        }

        guard isLikelyWindowsDateToken(String(columns[0])),
              isLikelyWindowsTimeToken(String(columns[1])) else {
            return nil
        }

        let name = columns[(dirIndex + 1)...]
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard name != ".", name != "..", !name.isEmpty else {
            return nil
        }

        return RemoteDirectoryItem(
            name: name,
            fullPath: BrowserPathNormalizer.join(base: basePath, child: name),
            isDirectory: true,
            modifiedAt: parseWindowsTimestamp(columns: columns, dirIndex: dirIndex),
            sizeBytes: nil
        )
    }

    private static func isLikelyWindowsDirectoryLine(_ line: String) -> Bool {
        let columns = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard columns.count >= 4 else {
            return false
        }

        guard let dirIndex = columns.firstIndex(where: { String($0).caseInsensitiveCompare("<DIR>") == .orderedSame }),
              dirIndex + 1 < columns.count else {
            return false
        }

        return isLikelyWindowsDateToken(String(columns[0]))
            && isLikelyWindowsTimeToken(String(columns[1]))
            && (dirIndex == 2 || (dirIndex == 3 && isAMPMToken(columns[2])))
    }

    private static func isLikelyWindowsDateToken(_ value: String) -> Bool {
        let parts = value.split(separator: "/")
        guard parts.count == 3 else {
            return false
        }
        return parts.allSatisfy { Int($0) != nil }
    }

    private static func isLikelyWindowsTimeToken(_ value: String) -> Bool {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return false
        }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }

    private static func isAMPMToken(_ value: Substring) -> Bool {
        let upper = value.uppercased()
        return upper == "AM" || upper == "PM"
    }

    private static func parseUNIXTimestamp(columns: [Substring]) -> Date? {
        guard columns.count >= 8 else {
            return nil
        }
        let month = String(columns[5])
        let day = String(columns[6])
        let yearOrTime = String(columns[7])
        if yearOrTime.contains(":") {
            let year = Calendar(identifier: .gregorian).component(.year, from: Date())
            let token = "\(month) \(day) \(year) \(yearOrTime)"
            return parseDate(token, formatters: [unixDateTimeFormatter])
        }
        let token = "\(month) \(day) \(yearOrTime)"
        return parseDate(token, formatters: [unixDateFormatter])
    }

    private static func parseWindowsTimestamp(columns: [Substring], dirIndex: Int) -> Date? {
        guard columns.count >= 3, dirIndex >= 2 else {
            return nil
        }
        let dateToken = String(columns[0])
        let timeToken = String(columns[1])

        if dirIndex == 3, isAMPMToken(columns[2]) {
            let stamp = "\(dateToken) \(timeToken) \(String(columns[2]))"
            return parseDate(stamp, formatters: windows12HourFormatters)
        }

        if dirIndex == 2 {
            let stamp = "\(dateToken) \(timeToken)"
            return parseDate(stamp, formatters: windows24HourFormatters)
        }

        return nil
    }

    private static func parseDate(_ value: String, formatters: [DateFormatter]) -> Date? {
        timestampFormatterLock.lock()
        defer { timestampFormatterLock.unlock() }
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = parserLocale
        formatter.timeZone = parserTimeZone
        formatter.dateFormat = format
        return formatter
    }
}
