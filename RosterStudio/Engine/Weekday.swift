import Foundation

/// A day of the scheduling week. `rawValue` doubles as the day index used by
/// the package's minute-of-week arithmetic, so Monday is `0`.
public enum Weekday: Int, CaseIterable, Codable, Sendable, Hashable {
    case monday = 0
    case tuesday = 1
    case wednesday = 2
    case thursday = 3
    case friday = 4
    case saturday = 5
    case sunday = 6

    /// Three-letter label used by diagnostics and exports.
    public var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    /// Full English name.
    public var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    /// The following day. Sunday wraps to Monday.
    public func next() -> Weekday {
        Weekday(rawValue: (rawValue + 1) % Weekday.allCases.count) ?? .monday
    }

    /// Weekend days, which many rosters treat as a separate pay band.
    public var isWeekend: Bool {
        self == .saturday || self == .sunday
    }
}
