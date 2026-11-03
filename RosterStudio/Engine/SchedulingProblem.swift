import Foundation

/// A complete rostering input: the people and the slots that need covering.
public struct SchedulingProblem: Hashable, Codable, Sendable {
    public var employees: [Employee]
    public var slots: [ShiftSlot]

    public init(employees: [Employee], slots: [ShiftSlot]) {
        self.employees = employees
        self.slots = slots
    }

    /// Looks up an employee by identifier.
    public func employee(id: String) -> Employee? {
        employees.first { $0.id == id }
    }

    /// Looks up a slot by identifier.
    public func slot(id: String) -> ShiftSlot? {
        slots.first { $0.id == id }
    }

    /// Total person-minutes the slots ask for, ignoring availability.
    public var requiredMinutes: Int {
        slots.reduce(0) { partial, slot in
            partial + slot.lengthMinutes * max(0, slot.requiredHeadcount)
        }
    }

    /// Structural validation. The solver refuses to run on a problem that has
    /// at least one `.error` issue; warnings are informational only.
    public func validate() -> [ProblemIssue] {
        var issues: [ProblemIssue] = []

        var employeeIDs = Set<String>()
        for employee in employees {
            let subject = employee.id.isEmpty ? "<unnamed-employee>" : employee.id

            if employee.id.isEmpty {
                issues.append(.error(
                    code: "employee.empty-id",
                    subject: subject,
                    message: "Employee identifiers must not be empty."
                ))
            }

            if !employeeIDs.insert(employee.id).inserted {
                issues.append(.error(
                    code: "employee.duplicate-id",
                    subject: subject,
                    message: "Another employee already uses this identifier."
                ))
            }

            if employee.maximumWeeklyMinutes <= 0 {
                issues.append(.error(
                    code: "employee.weekly-cap",
                    subject: subject,
                    message: "maximumWeeklyMinutes must be greater than zero."
                ))
            }

            if let daily = employee.maximumDailyMinutes, daily <= 0 {
                issues.append(.error(
                    code: "employee.daily-cap",
                    subject: subject,
                    message: "maximumDailyMinutes must be greater than zero when set."
                ))
            }

            if employee.minimumRestMinutes < 0 {
                issues.append(.error(
                    code: "employee.rest",
                    subject: subject,
                    message: "minimumRestMinutes must not be negative."
                ))
            }

            if employee.maximumConsecutiveDays < 0 {
                issues.append(.error(
                    code: "employee.consecutive-days",
                    subject: subject,
                    message: "maximumConsecutiveDays must not be negative."
                ))
            }

            if employee.roles.isEmpty {
                issues.append(.warning(
                    code: "employee.no-roles",
                    subject: subject,
                    message: "Employee holds no roles and can never be scheduled."
                ))
            }

            for range in employee.availability where !range.isValid {
                issues.append(.error(
                    code: "employee.availability",
                    subject: subject,
                    message: "Availability window \(range.start)-\(range.end) is empty or outside the week."
                ))
            }

            for range in employee.unavailability where !range.isValid {
                issues.append(.error(
                    code: "employee.unavailability",
                    subject: subject,
                    message: "Unavailability window \(range.start)-\(range.end) is empty or outside the week."
                ))
            }
        }

        var slotIDs = Set<String>()
        for slot in slots {
            let subject = slot.id.isEmpty ? "<unnamed-slot>" : slot.id

            if slot.id.isEmpty {
                issues.append(.error(
                    code: "slot.empty-id",
                    subject: subject,
                    message: "Slot identifiers must not be empty."
                ))
            }

            if !slotIDs.insert(slot.id).inserted {
                issues.append(.error(
                    code: "slot.duplicate-id",
                    subject: subject,
                    message: "Another slot already uses this identifier."
                ))
            }

            if slot.lengthMinutes <= 0 {
                issues.append(.error(
                    code: "slot.length",
                    subject: subject,
                    message: "lengthMinutes must be greater than zero."
                ))
            }

            if slot.startMinute < 0 || slot.startMinute >= WeekClock.minutesPerWeek {
                issues.append(.error(
                    code: "slot.start",
                    subject: subject,
                    message: "startMinute must fall inside the week."
                ))
            }

            if slot.startMinute + slot.lengthMinutes > WeekClock.minutesPerWeek {
                issues.append(.error(
                    code: "slot.week-overflow",
                    subject: subject,
                    message: "The slot ends after the end of the week."
                ))
            }

            if slot.requiredHeadcount <= 0 {
                issues.append(.error(
                    code: "slot.headcount",
                    subject: subject,
                    message: "requiredHeadcount must be greater than zero."
                ))
            }

            if slot.priority < 0 {
                issues.append(.error(
                    code: "slot.priority",
                    subject: subject,
                    message: "priority must not be negative."
                ))
            }

            if let allowed = slot.eligibleEmployeeIDs, allowed.isEmpty {
                issues.append(.warning(
                    code: "slot.empty-allow-list",
                    subject: subject,
                    message: "The allow-list is empty, so nobody can take this slot."
                ))
            }
        }

        return issues
    }

    /// Only the issues that stop the solver from running.
    public var errors: [ProblemIssue] {
        validate().filter { $0.severity == .error }
    }
}
