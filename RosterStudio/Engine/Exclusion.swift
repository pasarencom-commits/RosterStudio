import Foundation

/// Why an employee cannot take a particular slot, independent of what anybody
/// else is assigned to.
public enum ExclusionCause: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    case roleMismatch
    case restrictedToOtherEmployees
    case outsideAvailability
    case unavailableWindow
    case weeklyCapacityTooSmall

    public var description: String {
        switch self {
        case .roleMismatch: return "does not hold the required role"
        case .restrictedToOtherEmployees: return "not on the slot's allow-list"
        case .outsideAvailability: return "shift is outside availability"
        case .unavailableWindow: return "shift overlaps an unavailable window"
        case .weeklyCapacityTooSmall: return "weekly cap is shorter than the shift"
        }
    }
}

extension Employee {
    /// Returns the first reason this employee cannot take `slot`, or `nil` when
    /// the slot is compatible. This is the static half of eligibility; dynamic
    /// constraints (overlaps, rest, remaining cap) are checked by the solver.
    public func exclusionReason(for slot: ShiftSlot) -> ExclusionCause? {
        if let allowed = slot.eligibleEmployeeIDs, !allowed.contains(id) {
            return .restrictedToOtherEmployees
        }
        if !roles.contains(slot.role) {
            return .roleMismatch
        }
        if maximumWeeklyMinutes < slot.lengthMinutes {
            return .weeklyCapacityTooSmall
        }
        if !availability.isEmpty, !availability.contains(where: { $0.contains(slot.range) }) {
            return .outsideAvailability
        }
        if unavailability.contains(where: { $0.overlaps(slot.range) }) {
            return .unavailableWindow
        }
        return nil
    }

    /// `true` when the slot is statically compatible with this employee.
    public func isEligible(for slot: ShiftSlot) -> Bool {
        exclusionReason(for: slot) == nil
    }
}
