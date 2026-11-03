import Foundation

/// The weights used by the objective.
///
/// Every term is a non-negative penalty, so a lower total is always better and
/// the solver can prune safely. Coverage dominates preferences, and preferences
/// dominate the fairness term.
public enum Scoring {
    /// Penalty for leaving one unit of a priority 1 slot uncovered.
    public static let coverageUnitPenalty = 1_000
    /// Cost of assigning a neutral employee.
    public static let neutralAssignmentPenalty = 1
    /// Cost of assigning an employee who asked to avoid the slot.
    public static let avoidedAssignmentPenalty = 6
    /// Fairness is measured in half-hour blocks.
    public static let fairnessDivisor = 30

    /// Coverage weight of a slot: higher priority slots are more expensive to
    /// leave uncovered.
    public static func coverageWeight(for slot: ShiftSlot) -> Int {
        coverageUnitPenalty * max(1, slot.priority)
    }

    /// Cost of assigning `employee` to `slot`.
    public static func assignmentPenalty(_ employee: Employee, slot: ShiftSlot) -> Int {
        if employee.avoidedSlotIDs.contains(slot.id) { return avoidedAssignmentPenalty }
        if employee.preferredSlotIDs.contains(slot.id) { return 0 }
        return neutralAssignmentPenalty
    }

    /// `0` for preferred, `1` for neutral, `2` for avoided. Used only to order
    /// candidates deterministically.
    public static func preferenceRank(_ employee: Employee, slot: ShiftSlot) -> Int {
        if employee.avoidedSlotIDs.contains(slot.id) { return 2 }
        if employee.preferredSlotIDs.contains(slot.id) { return 0 }
        return 1
    }
}
