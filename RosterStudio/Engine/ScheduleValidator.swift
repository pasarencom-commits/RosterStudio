import Foundation

/// One way a schedule breaks the problem's constraints. Coverage gaps are
/// reported only when explicitly requested, because a best-effort schedule is
/// allowed to have them.
public struct ScheduleViolation: Hashable, Codable, Sendable, CustomStringConvertible {
    public enum Kind: String, Codable, Sendable, Hashable {
        case duplicateAssignment
        case unknownSlot
        case unknownEmployee
        case roleMismatch
        case restrictedEmployee
        case outsideAvailability
        case unavailableWindow
        case weeklyLimitExceeded
        case dailyLimitExceeded
        case overlappingShift
        case insufficientRest
        case tooManyConsecutiveDays
        case headcountExceeded
        case uncoveredSlot

        /// Whether this violation means the schedule is unusable, as opposed to
        /// merely incomplete.
        public var isConstraintViolation: Bool {
            self != .uncoveredSlot
        }
    }

    public let kind: Kind
    public let slotID: String
    public let employeeID: String
    public let message: String

    public init(kind: Kind, slotID: String = "", employeeID: String = "", message: String) {
        self.kind = kind
        self.slotID = slotID
        self.employeeID = employeeID
        self.message = message
    }

    public var description: String { message }
}

/// Re-derives every constraint from scratch instead of trusting the solver.
/// Shipping this next to the solver is what makes the output auditable.
public enum ScheduleValidator {
    /// Constraint checks for `schedule`.
    ///
    /// - Parameter includeCoverageGaps: When `true`, slots with fewer people
    ///   than they need are reported as `.uncoveredSlot`.
    public static func violations(
        in schedule: Schedule,
        for problem: SchedulingProblem,
        includeCoverageGaps: Bool = false
    ) -> [ScheduleViolation] {
        let slotsByID = Dictionary(
            problem.slots.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let employeesByID = Dictionary(
            problem.employees.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var violations: [ScheduleViolation] = []
        var seenAssignments = Set<String>()
        var counts: [String: Int] = [:]

        for assignment in schedule.assignments {
            let key = "\(assignment.slotID)\u{1F}\(assignment.employeeID)"
            if !seenAssignments.insert(key).inserted {
                violations.append(ScheduleViolation(
                    kind: .duplicateAssignment,
                    slotID: assignment.slotID,
                    employeeID: assignment.employeeID,
                    message: "\(assignment.employeeID) is assigned to \(assignment.slotID) more than once."
                ))
                continue
            }

            guard let slot = slotsByID[assignment.slotID] else {
                violations.append(ScheduleViolation(
                    kind: .unknownSlot,
                    slotID: assignment.slotID,
                    employeeID: assignment.employeeID,
                    message: "Unknown slot \(assignment.slotID)."
                ))
                continue
            }

            counts[slot.id, default: 0] += 1

            guard let employee = employeesByID[assignment.employeeID] else {
                violations.append(ScheduleViolation(
                    kind: .unknownEmployee,
                    slotID: slot.id,
                    employeeID: assignment.employeeID,
                    message: "Unknown employee \(assignment.employeeID)."
                ))
                continue
            }

            if let cause = employee.exclusionReason(for: slot) {
                violations.append(ScheduleViolation(
                    kind: kind(for: cause),
                    slotID: slot.id,
                    employeeID: employee.id,
                    message: "\(employee.id) cannot take \(slot.id): \(cause)."
                ))
            }
        }

        for employee in problem.employees {
            var seenSlots = Set<String>()
            let entries = schedule.assignments.compactMap { assignment -> (slot: ShiftSlot, assignment: Assignment)? in
                guard assignment.employeeID == employee.id else { return nil }
                guard let slot = slotsByID[assignment.slotID] else { return nil }
                guard seenSlots.insert(slot.id).inserted else { return nil }
                return (slot, assignment)
            }

            let ordered = entries.sorted { lhs, rhs in
                if lhs.slot.startMinute != rhs.slot.startMinute {
                    return lhs.slot.startMinute < rhs.slot.startMinute
                }
                return lhs.slot.id < rhs.slot.id
            }

            let totalMinutes = ordered.reduce(0) { $0 + $1.slot.lengthMinutes }
            if totalMinutes > employee.maximumWeeklyMinutes {
                violations.append(ScheduleViolation(
                    kind: .weeklyLimitExceeded,
                    employeeID: employee.id,
                    message: "\(employee.id) has \(totalMinutes) minutes, weekly cap is \(employee.maximumWeeklyMinutes)."
                ))
            }

            if ordered.count > 1 {
                for index in 1..<ordered.count {
                    let previous = ordered[index - 1].slot
                    let current = ordered[index].slot
                    if previous.range.overlaps(current.range) {
                        violations.append(ScheduleViolation(
                            kind: .overlappingShift,
                            slotID: current.id,
                            employeeID: employee.id,
                            message: "\(employee.id) works \(previous.id) and \(current.id), which overlap."
                        ))
                        continue
                    }
                    let gap = previous.range.gap(to: current.range)
                    if gap < employee.minimumRestMinutes {
                        violations.append(ScheduleViolation(
                            kind: .insufficientRest,
                            slotID: current.id,
                            employeeID: employee.id,
                            message: "\(employee.id) has \(gap) minutes of rest before \(current.id), needs \(employee.minimumRestMinutes)."
                        ))
                    }
                }
            }

            if let dailyLimit = employee.maximumDailyMinutes {
                var perDay: [Int: Int] = [:]
                for entry in ordered {
                    for day in WeekMath.days(touchedBy: entry.slot.range) {
                        perDay[day, default: 0] += WeekMath.overlappingMinutes(of: entry.slot.range, onDay: day)
                    }
                }
                for day in perDay.keys.sorted() {
                    let minutes = perDay[day] ?? 0
                    if minutes > dailyLimit {
                        violations.append(ScheduleViolation(
                            kind: .dailyLimitExceeded,
                            employeeID: employee.id,
                            message: "\(employee.id) has \(minutes) minutes on day \(day), daily cap is \(dailyLimit)."
                        ))
                    }
                }
            }

            let days = Set(ordered.flatMap { WeekMath.days(touchedBy: $0.slot.range) })
            let longestRun = WeekMath.longestConsecutiveRun(of: days)
            if longestRun > employee.maximumConsecutiveDays {
                violations.append(ScheduleViolation(
                    kind: .tooManyConsecutiveDays,
                    employeeID: employee.id,
                    message: "\(employee.id) works \(longestRun) consecutive days, limit is \(employee.maximumConsecutiveDays)."
                ))
            }
        }

        for slot in problem.slots {
            let count = counts[slot.id] ?? 0
            if count > slot.requiredHeadcount {
                violations.append(ScheduleViolation(
                    kind: .headcountExceeded,
                    slotID: slot.id,
                    message: "\(slot.id) has \(count) people assigned, needs \(slot.requiredHeadcount)."
                ))
            }
            if includeCoverageGaps, count < slot.requiredHeadcount {
                violations.append(ScheduleViolation(
                    kind: .uncoveredSlot,
                    slotID: slot.id,
                    message: "\(slot.id) has \(count) people assigned, needs \(slot.requiredHeadcount)."
                ))
            }
        }

        return violations
    }

    /// `true` when the schedule satisfies every hard constraint.
    public static func isValid(_ schedule: Schedule, for problem: SchedulingProblem) -> Bool {
        !violations(in: schedule, for: problem).contains { $0.kind.isConstraintViolation }
    }

    private static func kind(for cause: ExclusionCause) -> ScheduleViolation.Kind {
        switch cause {
        case .roleMismatch: return .roleMismatch
        case .restrictedToOtherEmployees: return .restrictedEmployee
        case .outsideAvailability: return .outsideAvailability
        case .unavailableWindow: return .unavailableWindow
        case .weeklyCapacityTooSmall: return .weeklyLimitExceeded
        }
    }
}
