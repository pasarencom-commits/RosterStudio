import Foundation

/// The package's linear time model.
///
/// Every instant in the scheduling week is an `Int` minute between `0` and
/// `WeekClock.minutesPerWeek`, counted from Monday 00:00. Working in plain
/// integers keeps the solver deterministic and free of calendar, time zone and
/// daylight-saving surprises; `ICSExporter` is the only place that converts
/// back to `Date`.
public enum WeekClock {
    /// Minutes in one day.
    public static let minutesPerDay = 1_440
    /// Minutes in one week, Monday 00:00 ..< next Monday 00:00.
    public static let minutesPerWeek = 10_080

    /// Builds an absolute minute-of-week value from a day and a wall clock time.
    ///
    /// - Parameters:
    ///   - day: The day to anchor on.
    ///   - hour: Hours after midnight. Values above 23 are allowed so callers can
    ///     express a boundary such as "end of day" as `hour: 24`.
    ///   - minute: Minutes after the hour.
    public static func minute(day: Weekday, hour: Int, minute: Int = 0) -> Int {
        day.rawValue * minutesPerDay + hour * 60 + minute
    }

    /// Formats a minute inside a day as `HH:mm`, wrapping negatives forward.
    public static func clockLabel(_ minuteOfDay: Int) -> String {
        let normalized = ((minuteOfDay % minutesPerDay) + minutesPerDay) % minutesPerDay
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

/// A half-open interval `[start, end)` on the minute-of-week axis.
///
/// Initialisation does not validate: an out-of-range range is representable so
/// that `SchedulingProblem.validate()` can report it instead of trapping.
public struct MinuteRange: Hashable, Codable, Sendable, CustomStringConvertible {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    /// Minutes covered by the range; never negative.
    public var length: Int { max(0, end - start) }

    /// `true` when the range lies inside one week and is non-empty.
    public var isValid: Bool {
        start >= 0 && end > start && end <= WeekClock.minutesPerWeek
    }

    /// The day the range starts on, or `nil` for an out-of-week start.
    public var weekday: Weekday? {
        guard start >= 0, start < WeekClock.minutesPerWeek else { return nil }
        return Weekday(rawValue: start / WeekClock.minutesPerDay)
    }

    /// `true` when `minute` falls inside the range.
    public func contains(_ minute: Int) -> Bool {
        minute >= start && minute < end
    }

    /// `true` when `other` is fully inside the receiver.
    public func contains(_ other: MinuteRange) -> Bool {
        other.start >= start && other.end <= end
    }

    /// `true` when the two ranges share at least one minute. Adjacent ranges do
    /// not overlap.
    public func overlaps(_ other: MinuteRange) -> Bool {
        start < other.end && other.start < end
    }

    /// The shared portion, or `nil` when the ranges are disjoint.
    public func intersection(with other: MinuteRange) -> MinuteRange? {
        let lower = max(start, other.start)
        let upper = min(end, other.end)
        return lower < upper ? MinuteRange(start: lower, end: upper) : nil
    }

    /// Minutes between the two ranges; `0` when they touch or overlap.
    public func gap(to other: MinuteRange) -> Int {
        if other.start >= end { return other.start - end }
        if start >= other.end { return start - other.end }
        return 0
    }

    /// Everything the receiver covers that `other` does not.
    public func subtracting(_ other: MinuteRange) -> [MinuteRange] {
        guard overlaps(other) else { return [self] }
        var pieces: [MinuteRange] = []
        if start < other.start {
            pieces.append(MinuteRange(start: start, end: other.start))
        }
        if other.end < end {
            pieces.append(MinuteRange(start: other.end, end: end))
        }
        return pieces
    }

    /// Human readable label such as `Mon 09:00-17:00 (8h)`.
    public var formatted: String {
        guard let day = weekday else { return "\(start)-\(end)m" }
        let startOfDay = start % WeekClock.minutesPerDay
        let endOfDay = end % WeekClock.minutesPerDay
        return "\(day.shortName) \(WeekClock.clockLabel(startOfDay))-\(WeekClock.clockLabel(endOfDay)) (\(durationLabel))"
    }

    /// Duration rendered as `45m`, `8h` or `7h 30m`.
    public var durationLabel: String {
        let hours = length / 60
        let minutes = length % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    public var description: String { formatted }
}

/// Shared day/minute arithmetic used by the validator and the solver.
enum WeekMath {
    /// Day indices a range touches. Cross-midnight ranges (for example a
    /// 22:00-02:00 shift) return two days.
    static func days(touchedBy range: MinuteRange) -> [Int] {
        guard range.end > range.start else { return [] }
        let first = range.start / WeekClock.minutesPerDay
        let last = (range.end - 1) / WeekClock.minutesPerDay
        guard last >= first, first >= 0, last <= 6 else { return [] }
        return Array(first...last)
    }

    /// Minutes of `range` that fall on `day`.
    static func overlappingMinutes(of range: MinuteRange, onDay day: Int) -> Int {
        let dayStart = day * WeekClock.minutesPerDay
        let dayEnd = dayStart + WeekClock.minutesPerDay
        let lower = max(range.start, dayStart)
        let upper = min(range.end, dayEnd)
        return max(0, upper - lower)
    }

    /// Longest run of consecutive day indices in `days`.
    static func longestConsecutiveRun(of days: Set<Int>) -> Int {
        guard let first = days.min() else { return 0 }
        let sorted = days.sorted()
        var longest = 1
        var current = 1
        var previous = first
        for day in sorted.dropFirst() {
            if day == previous + 1 {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
    }
}
