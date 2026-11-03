import Foundation

/// A block of work that needs to be covered, described on the minute-of-week
/// axis. A slot may cross midnight (for example `22:00-02:00`) as long as it
/// stays inside the same week.
public struct ShiftSlot: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let role: Role
    /// Minute of week at which the slot starts.
    public let startMinute: Int
    /// Length of the slot in minutes. Must be positive.
    public let lengthMinutes: Int
    /// How many people the slot needs.
    public let requiredHeadcount: Int
    /// Relative importance, used by the solver to decide which slot to leave
    /// uncovered when the roster cannot cover everything. Higher is better and
    /// must be non-negative.
    public let priority: Int
    /// Optional allow-list of employee ids. `nil` means "anyone with the role".
    public let eligibleEmployeeIDs: Set<String>?

    public init(
        id: String,
        role: Role,
        startMinute: Int,
        lengthMinutes: Int,
        requiredHeadcount: Int = 1,
        priority: Int = 1,
        eligibleEmployeeIDs: Set<String>? = nil
    ) {
        self.id = id
        self.role = role
        self.startMinute = startMinute
        self.lengthMinutes = lengthMinutes
        self.requiredHeadcount = requiredHeadcount
        self.priority = priority
        self.eligibleEmployeeIDs = eligibleEmployeeIDs
    }

    /// Minute of week at which the slot ends (exclusive).
    public var endMinute: Int { startMinute + lengthMinutes }

    /// The slot expressed as a `MinuteRange`.
    public var range: MinuteRange { MinuteRange(start: startMinute, end: endMinute) }

    /// The day the slot starts on.
    public var weekday: Weekday? { range.weekday }

    /// Label such as `Mon 09:00-17:00 (8h)`.
    public var formatted: String { range.formatted }

    /// `true` when the slot lies inside one week.
    public var isValid: Bool {
        startMinute >= 0
            && lengthMinutes > 0
            && startMinute + lengthMinutes <= WeekClock.minutesPerWeek
    }
}
