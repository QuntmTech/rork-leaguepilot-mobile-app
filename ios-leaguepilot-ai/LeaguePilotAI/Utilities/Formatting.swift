import Foundation

/// Human-readable error text for network failures.
enum FriendlyError {
    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Pull down to try again."
    }
}

/// Parses PocketBase timestamps and renders short relative strings ("2m ago").
enum RelativeTime {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    /// Parses PocketBase timestamps ("2026-08-28 09:41:00.000Z") tolerantly.
    static func date(from timestamp: String) -> Date? {
        if let date = fractional.date(from: timestamp) { return date }
        if let date = plain.date(from: timestamp) { return date }
        let spaced = timestamp.replacingOccurrences(of: " ", with: "T")
        return plain.date(from: spaced) ?? fractional.date(from: spaced)
    }

    /// Short relative string, e.g. "2m ago".
    static func string(from timestamp: String) -> String {
        guard let date = date(from: timestamp) else { return "time unavailable" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
