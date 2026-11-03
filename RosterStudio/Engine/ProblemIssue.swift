import Foundation

/// A problem with the input data, reported instead of trapping or silently
/// dropping data.
public struct ProblemIssue: Hashable, Codable, Sendable, CustomStringConvertible {
    public enum Severity: String, Codable, Sendable, Hashable {
        case error
        case warning
    }

    public let severity: Severity
    /// Stable machine readable code, for example `slot.duplicate-id`.
    public let code: String
    /// The employee or slot the issue refers to.
    public let subject: String
    public let message: String

    public init(severity: Severity, code: String, subject: String, message: String) {
        self.severity = severity
        self.code = code
        self.subject = subject
        self.message = message
    }

    public static func error(code: String, subject: String, message: String) -> ProblemIssue {
        ProblemIssue(severity: .error, code: code, subject: subject, message: message)
    }

    public static func warning(code: String, subject: String, message: String) -> ProblemIssue {
        ProblemIssue(severity: .warning, code: code, subject: subject, message: message)
    }

    public var description: String {
        "[\(severity.rawValue)] \(code) \(subject): \(message)"
    }
}
