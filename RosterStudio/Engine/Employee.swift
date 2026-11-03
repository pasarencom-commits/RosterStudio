import Foundation

/// A person who can be scheduled.
///
/// Availability is expressed as weekly windows on the minute-of-week axis. An
/// empty `availability` array means "available at any time"; a shift must be
/// fully contained in a single window to be considered available, which keeps
/// the semantics easy to reason about in diagnostics.
public struct Employee: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let roles: Set<Role>
    public let availability: [MinuteRange]
    public let unavailability: [MinuteRange]
    /// Hard cap on assigned minutes per week.
    public let maximumWeeklyMinutes: Int
    /// Optional hard cap on assigned minutes per calendar day.
    public let maximumDailyMinutes: Int?
    /// Minimum minutes off between the end of one shift and the start of the
    /// next one.
    public let minimumRestMinutes: Int
    /// Maximum number of consecutive days with at least one shift.
    public let maximumConsecutiveDays: Int
    /// Slots this person would like to work.
    public let preferredSlotIDs: Set<String>
    /// Slots this person would rather avoid.
    public let avoidedSlotIDs: Set<String>

    public init(
        id: String,
        name: String,
        roles: Set<Role>,
        availability: [MinuteRange] = [],
        unavailability: [MinuteRange] = [],
        maximumWeeklyMinutes: Int = WeekClock.minutesPerWeek,
        maximumDailyMinutes: Int? = nil,
        minimumRestMinutes: Int = 0,
        maximumConsecutiveDays: Int = 7,
        preferredSlotIDs: Set<String> = [],
        avoidedSlotIDs: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.roles = roles
        self.availability = availability
        self.unavailability = unavailability
        self.maximumWeeklyMinutes = maximumWeeklyMinutes
        self.maximumDailyMinutes = maximumDailyMinutes
        self.minimumRestMinutes = minimumRestMinutes
        self.maximumConsecutiveDays = maximumConsecutiveDays
        self.preferredSlotIDs = preferredSlotIDs
        self.avoidedSlotIDs = avoidedSlotIDs
    }

    /// `name` when it is non-empty, otherwise the identifier.
    public var displayName: String { name.isEmpty ? id : name }
}
