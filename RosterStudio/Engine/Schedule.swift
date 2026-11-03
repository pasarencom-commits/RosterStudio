import Foundation

/// One person covering one slot.
public struct Assignment: Hashable, Codable, Sendable, Identifiable {
    public let slotID: String
    public let employeeID: String

    public init(slotID: String, employeeID: String) {
        self.slotID = slotID
        self.employeeID = employeeID
    }

    public var id: String { "\(slotID)#\(employeeID)" }
}

/// The objective broken into its parts. `total` is the number the solver
/// minimises; every field is non-negative.
public struct ScoreBreakdown: Hashable, Codable, Sendable {
    /// Units of demand that nobody covers.
    public var uncoveredUnits: Int
    /// Penalty from `uncoveredUnits`, weighted by slot priority.
    public var coveragePenalty: Int
    /// Penalty from neutral and avoided assignments.
    public var preferencePenalty: Int
    /// Penalty for unevenly distributed minutes.
    public var fairnessPenalty: Int
    /// Sum of the terms above.
    public var total: Int

    public init(
        uncoveredUnits: Int,
        coveragePenalty: Int,
        preferencePenalty: Int,
        fairnessPenalty: Int,
        total: Int
    ) {
        self.uncoveredUnits = uncoveredUnits
        self.coveragePenalty = coveragePenalty
        self.preferencePenalty = preferencePenalty
        self.fairnessPenalty = fairnessPenalty
        self.total = total
    }

    public static let zero = ScoreBreakdown(
        uncoveredUnits: 0,
        coveragePenalty: 0,
        preferencePenalty: 0,
        fairnessPenalty: 0,
        total: 0
    )

    /// `true` when every unit of demand is covered.
    public var isFullyCovered: Bool { uncoveredUnits == 0 }
}

/// A solved roster: which employee covers which slot, plus the objective value
/// that produced it.
public struct Schedule: Hashable, Codable, Sendable {
    public var assignments: [Assignment]
    public var score: ScoreBreakdown

    public init(assignments: [Assignment], score: ScoreBreakdown = .zero) {
        self.assignments = assignments
        self.score = score
    }

    public var isEmpty: Bool { assignments.isEmpty }

    /// Employee identifiers covering `slotID`, sorted for stable output.
    public func employeeIDs(forSlot slotID: String) -> [String] {
        assignments.filter { $0.slotID == slotID }.map { $0.employeeID }.sorted()
    }

    /// Assigned minutes per employee, using the slot lengths from `problem`.
    public func minutesByEmployee(for problem: SchedulingProblem) -> [String: Int] {
        let lengths = Dictionary(
            problem.slots.map { ($0.id, $0.lengthMinutes) },
            uniquingKeysWith: { first, _ in first }
        )
        var totals: [String: Int] = [:]
        for assignment in assignments {
            guard let length = lengths[assignment.slotID] else { continue }
            totals[assignment.employeeID, default: 0] += length
        }
        return totals
    }

    /// Canonical, stable text form used for the fingerprint.
    public var canonicalForm: String {
        assignments
            .map { "\($0.slotID)\u{1F}\($0.employeeID)" }
            .sorted()
            .joined(separator: "\n")
    }

    /// Stable 64-bit FNV-1a fingerprint of the assignment set. Two schedules
    /// with the same fingerprint have the same assignments.
    public var fingerprint: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x1000_0000_01b3
        for byte in canonicalForm.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}
