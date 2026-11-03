import Foundation

/// One employee who cannot take a slot, with the reason why.
public struct Exclusion: Hashable, Codable, Sendable {
    public let employeeID: String
    public let cause: ExclusionCause

    public init(employeeID: String, cause: ExclusionCause) {
        self.employeeID = employeeID
        self.cause = cause
    }
}

/// Proof that a single slot cannot be staffed: fewer eligible people than the
/// headcount it needs.
public struct InfeasibilityCertificate: Hashable, Codable, Sendable, CustomStringConvertible {
    public let slotID: String
    public let requiredHeadcount: Int
    public let eligibleCount: Int
    public let exclusions: [Exclusion]

    public init(slotID: String, requiredHeadcount: Int, eligibleCount: Int, exclusions: [Exclusion]) {
        self.slotID = slotID
        self.requiredHeadcount = requiredHeadcount
        self.eligibleCount = eligibleCount
        self.exclusions = exclusions
    }

    /// How many people are missing for this slot.
    public var shortfall: Int { max(0, requiredHeadcount - eligibleCount) }

    public var description: String {
        let detail = exclusions
            .map { "\($0.employeeID): \($0.cause)" }
            .joined(separator: "; ")
        return "slot \(slotID) needs \(requiredHeadcount), has \(eligibleCount) eligible"
            + (detail.isEmpty ? "" : " (\(detail))")
    }
}

/// Everything the engine can say about an infeasible problem.
public struct InfeasibilityReport: Hashable, Codable, Sendable, CustomStringConvertible {
    public let certificates: [InfeasibilityCertificate]
    /// How many search nodes were spent before giving up.
    public let searchedNodes: Int

    public init(certificates: [InfeasibilityCertificate], searchedNodes: Int) {
        self.certificates = certificates
        self.searchedNodes = searchedNodes
    }

    /// `true` when the report carries no static proof, which means the
    /// infeasibility is the result of interacting constraints rather than a
    /// single short-staffed slot.
    public var isEmpty: Bool { certificates.isEmpty }

    public var description: String {
        if certificates.isEmpty {
            return "no complete assignment exists (searched \(searchedNodes) nodes)"
        }
        return certificates.map(\.description).joined(separator: "\n")
    }
}
