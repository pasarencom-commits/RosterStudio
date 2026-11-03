import Foundation

/// A recurring pattern that expands into concrete slots, so callers do not have
/// to spell out every weekday by hand.
public struct ShiftTemplate: Hashable, Codable, Sendable {
    /// Prefix for generated identifiers. Generated ids have the form
    /// `<prefix>-d<weekday>-m<minuteOfDay>` and are stable across runs.
    public var idPrefix: String
    public var role: Role
    public var weekdays: Set<Weekday>
    /// Start time expressed as minutes after midnight.
    public var startMinuteOfDay: Int
    public var lengthMinutes: Int
    public var requiredHeadcount: Int
    public var priority: Int

    public init(
        idPrefix: String,
        role: Role,
        weekdays: Set<Weekday>,
        startMinuteOfDay: Int,
        lengthMinutes: Int,
        requiredHeadcount: Int = 1,
        priority: Int = 1
    ) {
        self.idPrefix = idPrefix
        self.role = role
        self.weekdays = weekdays
        self.startMinuteOfDay = startMinuteOfDay
        self.lengthMinutes = lengthMinutes
        self.requiredHeadcount = requiredHeadcount
        self.priority = priority
    }

    /// Expands the template, ordered Monday to Sunday.
    public func slots() -> [ShiftSlot] {
        weekdays
            .sorted { $0.rawValue < $1.rawValue }
            .map { day in
                ShiftSlot(
                    id: "\(idPrefix)-d\(day.rawValue)-m\(startMinuteOfDay)",
                    role: role,
                    startMinute: WeekClock.minute(
                        day: day,
                        hour: startMinuteOfDay / 60,
                        minute: startMinuteOfDay % 60
                    ),
                    lengthMinutes: lengthMinutes,
                    requiredHeadcount: requiredHeadcount,
                    priority: priority
                )
            }
    }
}
