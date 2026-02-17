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
final class MountStateParser {
    /// Beginner note: This method is one step in the feature workflow for this file.
    func parseMountOutput(_ output: String) -> [MountRecord] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                let lineString = String(line)
                guard let onRange = lineString.range(of: " on ") else {
                    return nil
                }
                guard let typeStart = lineString.range(of: " (", range: onRange.upperBound..<lineString.endIndex) else {
                    return nil
                }
                guard let typeEnd = lineString[typeStart.upperBound...].firstIndex(of: ")") else {
                    return nil
                }

                let source = decodeEscapedMountField(
                    lineString[..<onRange.lowerBound]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                let mountPoint = decodeEscapedMountField(
                    lineString[onRange.upperBound..<typeStart.lowerBound]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                let fsType = lineString[typeStart.upperBound..<typeEnd]
                    .split(separator: ",", maxSplits: 1)
                    .first
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !source.isEmpty, !mountPoint.isEmpty else {
                    return nil
                }

                return MountRecord(source: source, mountPoint: mountPoint, filesystemType: fsType)
            }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    func record(forMountPoint mountPoint: String, from records: [MountRecord]) -> MountRecord? {
        records.first { normalize($0.mountPoint) == normalize(mountPoint) }
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// Beginner note: This method is one step in the feature workflow for this file.
    private func decodeEscapedMountField(_ value: String) -> String {
        var output = value
        output = output.replacingOccurrences(of: "\\040", with: " ")
        output = output.replacingOccurrences(of: "\\011", with: "\t")
        output = output.replacingOccurrences(of: "\\012", with: "\n")
        output = output.replacingOccurrences(of: "\\\\", with: "\\")
        return output
    }
}
