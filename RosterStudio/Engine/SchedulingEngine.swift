import Foundation

/// Knobs for `SchedulingEngine.solve`.
public struct SolveOptions: Hashable, Codable, Sendable {
    /// Hard ceiling on search nodes. The ceiling makes solve time bounded even
    /// on adversarial input and keeps results reproducible across machines.
    public var maximumSteps: Int
    /// When `false`, a schedule must cover every unit of demand; the engine
    /// reports `.infeasible` instead of returning an incomplete roster.
    public var allowUnfilled: Bool
    /// How strongly to spread minutes across the schedulable employees.
    public var fairnessWeight: Int

    public init(maximumSteps: Int = 200_000, allowUnfilled: Bool = true, fairnessWeight: Int = 1) {
        self.maximumSteps = max(0, maximumSteps)
        self.allowUnfilled = allowUnfilled
        self.fairnessWeight = max(0, fairnessWeight)
    }
}

/// What the search actually did.
public struct SolverReport: Hashable, Codable, Sendable {
    public let nodesVisited: Int
    /// `true` when the node budget stopped the search early.
    public let budgetExhausted: Bool
    public let fullyCovered: Bool
    public let uncoveredUnits: Int
    public let totalPenalty: Int

    public init(
        nodesVisited: Int,
        budgetExhausted: Bool,
        fullyCovered: Bool,
        uncoveredUnits: Int,
        totalPenalty: Int
    ) {
        self.nodesVisited = nodesVisited
        self.budgetExhausted = budgetExhausted
        self.fullyCovered = fullyCovered
        self.uncoveredUnits = uncoveredUnits
        self.totalPenalty = totalPenalty
    }
}

/// The outcome of a solve.
public enum SolveResult: Sendable {
    /// The search finished; no better assignment exists under the objective.
    case optimal(Schedule, SolverReport)
    /// The node budget ran out before the search finished; this is the best
    /// roster found so far.
    case bestEffort(Schedule, SolverReport)
    /// No roster exists. `InfeasibilityReport` carries the proof when one is
    /// available.
    case infeasible(InfeasibilityReport)
    /// The input data is malformed.
    case invalid([ProblemIssue])

    public var schedule: Schedule? {
        switch self {
        case .optimal(let schedule, _), .bestEffort(let schedule, _):
            return schedule
        case .infeasible, .invalid:
            return nil
        }
    }

    public var report: SolverReport? {
        switch self {
        case .optimal(_, let report), .bestEffort(_, let report):
            return report
        case .infeasible, .invalid:
            return nil
        }
    }

    public var isSolved: Bool { schedule != nil }

    /// A human readable explanation for the failure cases.
    public var failureDescription: String? {
        switch self {
        case .optimal, .bestEffort:
            return nil
        case .infeasible(let report):
            return report.description
        case .invalid(let issues):
            return issues.map(\.description).joined(separator: "\n")
        }
    }
}

/// Deterministic rostering over the package's constraint model.
public enum SchedulingEngine {
    /// Static proof of why a slot can never be staffed, one certificate per
    /// short-staffed slot.
    public static func explain(_ problem: SchedulingProblem) -> [InfeasibilityCertificate] {
        var certificates: [InfeasibilityCertificate] = []
        for slot in problem.slots {
            var exclusions: [Exclusion] = []
            var eligibleCount = 0
            for employee in problem.employees {
                if let cause = employee.exclusionReason(for: slot) {
                    exclusions.append(Exclusion(employeeID: employee.id, cause: cause))
                } else {
                    eligibleCount += 1
                }
            }
            if eligibleCount < slot.requiredHeadcount {
                certificates.append(InfeasibilityCertificate(
                    slotID: slot.id,
                    requiredHeadcount: slot.requiredHeadcount,
                    eligibleCount: eligibleCount,
                    exclusions: exclusions
                ))
            }
        }
        return certificates
    }

    /// Solves the problem.
    ///
    /// The search is deterministic: candidates are ordered by employee id, the
    /// slot order is derived from the data, and the only stopping condition is
    /// the node budget. The same input therefore always produces the same
    /// output on every platform.
    public static func solve(
        _ problem: SchedulingProblem,
        options: SolveOptions = SolveOptions()
    ) -> SolveResult {
        let issues = problem.validate()
        if issues.contains(where: { $0.severity == .error }) {
            return .invalid(issues)
        }

        let certificates = explain(problem)
        if !options.allowUnfilled, !certificates.isEmpty {
            return .infeasible(InfeasibilityReport(certificates: certificates, searchedNodes: 0))
        }

        var search = RosterSearch(problem: problem, options: options)
        return search.run(certificates: certificates)
    }
}

/// Branch-and-bound search over slot assignments.
///
/// The search is exhaustive when the node budget allows it, so a completed run
/// is provably optimal for the objective in `Scoring`. Uncovered demand is
/// modelled as an explicit choice with a fixed penalty, which turns every
/// partial roster into a comparable solution and makes "best effort" meaningful.
struct RosterSearch {
    typealias Choice = (slot: Int, employee: Int)

    private let options: SolveOptions
    private let slots: [ShiftSlot]
    private let employees: [Employee]
    private let candidates: [[Int]]
    private let weights: [Int]
    private let order: [Int]
    private let schedulable: Set<Int>

    private var chosen: [Choice] = []
    private var best: (penalty: Int, chosen: [Choice])?
    private var nodes = 0
    private var exhausted = false

    init(problem: SchedulingProblem, options: SolveOptions) {
        self.options = options
        self.slots = problem.slots
        self.employees = problem.employees

        var lists: [[Int]] = []
        for slot in problem.slots {
            var list: [Int] = []
            for (index, employee) in problem.employees.enumerated() {
                if employee.exclusionReason(for: slot) == nil {
                    list.append(index)
                }
            }
            lists.append(list)
        }
        self.candidates = lists
        self.weights = problem.slots.map { Scoring.coverageWeight(for: $0) }
        self.order = problem.slots.indices.sorted { lhs, rhs in
            let left = problem.slots[lhs]
            let right = problem.slots[rhs]
            if lists[lhs].count != lists[rhs].count {
                return lists[lhs].count < lists[rhs].count
            }
            if left.requiredHeadcount != right.requiredHeadcount {
                return left.requiredHeadcount > right.requiredHeadcount
            }
            if left.startMinute != right.startMinute {
                return left.startMinute < right.startMinute
            }
            return left.id < right.id
        }
        self.schedulable = Set(lists.flatMap { $0 })
    }

    mutating func run(certificates: [InfeasibilityCertificate]) -> SolveResult {
        // A partial greedy roster is only a valid incumbent when the caller
        // allows unfilled demand; otherwise the seed would masquerade as a
        // feasible solution for an unsatisfiable problem.
        if options.allowUnfilled, let seed = greedySeed() {
            best = seed
        }

        descend(position: 0, partial: 0)

        guard let best = best else {
            return .infeasible(InfeasibilityReport(certificates: certificates, searchedNodes: nodes))
        }

        let breakdown = evaluate(best.chosen)
        let schedule = makeSchedule(best.chosen, score: breakdown)
        let report = SolverReport(
            nodesVisited: nodes,
            budgetExhausted: exhausted,
            fullyCovered: breakdown.uncoveredUnits == 0,
            uncoveredUnits: breakdown.uncoveredUnits,
            totalPenalty: breakdown.total
        )
        return exhausted ? .bestEffort(schedule, report) : .optimal(schedule, report)
    }

    // MARK: - Search

    private mutating func descend(position: Int, partial: Int) {
        if exhausted { return }
        if let best = best, partial >= best.penalty { return }
        if position >= order.count {
            finish(partial: partial)
            return
        }
        if nodes >= options.maximumSteps {
            exhausted = true
            return
        }
        nodes += 1

        let slotIndex = order[position]
        let slot = slots[slotIndex]
        let need = max(0, slot.requiredHeadcount)

        var feasible: [Int] = []
        for employeeIndex in candidates[slotIndex] {
            if fits(slotIndex: slotIndex, employeeIndex: employeeIndex) {
                feasible.append(employeeIndex)
            }
        }

        let minimumFill = options.allowUnfilled ? 0 : need
        if !options.allowUnfilled && feasible.count < need {
            return
        }
        let maximumFill = min(need, feasible.count)
        guard maximumFill >= minimumFill else { return }

        for fill in stride(from: maximumFill, through: minimumFill, by: -1) {
            if exhausted { return }
            let uncovered = need - fill
            let nextPartial = partial + uncovered * weights[slotIndex]
            if let best = best, nextPartial >= best.penalty { continue }
            if fill == 0 {
                descend(position: position + 1, partial: nextPartial)
            } else {
                choose(
                    slotIndex: slotIndex,
                    position: position,
                    pool: feasible,
                    remaining: fill,
                    start: 0,
                    partial: nextPartial,
                    selected: []
                )
            }
        }
    }

    private mutating func choose(
        slotIndex: Int,
        position: Int,
        pool: [Int],
        remaining: Int,
        start: Int,
        partial: Int,
        selected: [Int]
    ) {
        if exhausted { return }
        if remaining == 0 {
            let saved = chosen
            for employeeIndex in selected {
                chosen.append((slot: slotIndex, employee: employeeIndex))
            }
            descend(position: position + 1, partial: partial)
            chosen = saved
            return
        }
        if start > pool.count - remaining { return }
        if let best = best, partial >= best.penalty { return }
        if nodes >= options.maximumSteps {
            exhausted = true
            return
        }
        nodes += 1

        let lastStart = pool.count - remaining
        for index in start...lastStart {
            let employeeIndex = pool[index]
            guard fits(slotIndex: slotIndex, employeeIndex: employeeIndex) else { continue }
            let penalty = partial + Scoring.assignmentPenalty(employees[employeeIndex], slot: slots[slotIndex])
            var next = selected
            next.append(employeeIndex)
            choose(
                slotIndex: slotIndex,
                position: position,
                pool: pool,
                remaining: remaining - 1,
                start: index + 1,
                partial: penalty,
                selected: next
            )
        }
    }

    private mutating func finish(partial: Int) {
        let fairness = fairnessPenalty(chosen)
        let total = partial + fairness
        if let best = best, total >= best.penalty { return }
        best = (penalty: total, chosen: chosen)
    }

    // MARK: - Feasibility

    /// Checks the dynamic constraints (overlap, rest, remaining weekly and
    /// daily capacity, consecutive days) for one more assignment.
    private func fits(slotIndex: Int, employeeIndex: Int) -> Bool {
        let slot = slots[slotIndex]
        let employee = employees[employeeIndex]

        var totalMinutes = 0
        var perDay: [Int: Int] = [:]
        var days: Set<Int> = []

        for entry in chosen where entry.employee == employeeIndex {
            let other = slots[entry.slot]
            totalMinutes += other.lengthMinutes
            for day in WeekMath.days(touchedBy: other.range) {
                perDay[day, default: 0] += WeekMath.overlappingMinutes(of: other.range, onDay: day)
                days.insert(day)
            }
            if other.range.overlaps(slot.range) { return false }
            if other.range.gap(to: slot.range) < employee.minimumRestMinutes { return false }
        }

        if totalMinutes + slot.lengthMinutes > employee.maximumWeeklyMinutes {
            return false
        }

        if let dailyLimit = employee.maximumDailyMinutes {
            for day in WeekMath.days(touchedBy: slot.range) {
                let added = WeekMath.overlappingMinutes(of: slot.range, onDay: day)
                if perDay[day, default: 0] + added > dailyLimit {
                    return false
                }
            }
        }

        for day in WeekMath.days(touchedBy: slot.range) {
            days.insert(day)
        }
        if WeekMath.longestConsecutiveRun(of: days) > employee.maximumConsecutiveDays {
            return false
        }

        return true
    }

    // MARK: - Objective

    private func evaluate(_ choices: [Choice]) -> ScoreBreakdown {
        var covered: [Int: Int] = [:]
        var preference = 0
        for entry in choices {
            covered[entry.slot, default: 0] += 1
            preference += Scoring.assignmentPenalty(employees[entry.employee], slot: slots[entry.slot])
        }

        var uncoveredUnits = 0
        var coverage = 0
        for (index, slot) in slots.enumerated() {
            let missing = max(0, slot.requiredHeadcount - (covered[index] ?? 0))
            uncoveredUnits += missing
            coverage += missing * weights[index]
        }

        let fairness = fairnessPenalty(choices)
        return ScoreBreakdown(
            uncoveredUnits: uncoveredUnits,
            coveragePenalty: coverage,
            preferencePenalty: preference,
            fairnessPenalty: fairness,
            total: coverage + preference + fairness
        )
    }

    private func fairnessPenalty(_ choices: [Choice]) -> Int {
        guard !schedulable.isEmpty, options.fairnessWeight > 0 else { return 0 }
        var totals: [Int: Int] = [:]
        for index in schedulable {
            totals[index] = 0
        }
        for entry in choices {
            totals[entry.employee, default: 0] += slots[entry.slot].lengthMinutes
        }
        guard let minimum = totals.values.min(),
              let maximum = totals.values.max(),
              maximum > minimum else {
            return 0
        }
        return ((maximum - minimum) / Scoring.fairnessDivisor) * options.fairnessWeight
    }

    // MARK: - Construction

    private func makeSchedule(_ choices: [Choice], score: ScoreBreakdown) -> Schedule {
        let assignments = choices
            .map { Assignment(slotID: slots[$0.slot].id, employeeID: employees[$0.employee].id) }
            .sorted { lhs, rhs in
                if lhs.slotID != rhs.slotID { return lhs.slotID < rhs.slotID }
                return lhs.employeeID < rhs.employeeID
            }
        return Schedule(assignments: assignments, score: score)
    }

    /// A single deterministic pass used as the initial upper bound, which makes
    /// branch-and-bound prune far earlier.
    private mutating func greedySeed() -> (penalty: Int, chosen: [Choice])? {
        let saved = chosen
        chosen = []
        var penalty = 0

        for slotIndex in order {
            let slot = slots[slotIndex]
            var pool = candidates[slotIndex]
            pool.sort { lhs, rhs in
                let leftRank = Scoring.preferenceRank(employees[lhs], slot: slot)
                let rightRank = Scoring.preferenceRank(employees[rhs], slot: slot)
                if leftRank != rightRank { return leftRank < rightRank }
                return employees[lhs].id < employees[rhs].id
            }

            var filled = 0
            for employeeIndex in pool {
                if filled >= slot.requiredHeadcount { break }
                guard fits(slotIndex: slotIndex, employeeIndex: employeeIndex) else { continue }
                chosen.append((slot: slotIndex, employee: employeeIndex))
                penalty += Scoring.assignmentPenalty(employees[employeeIndex], slot: slot)
                filled += 1
            }

            if filled < slot.requiredHeadcount {
                penalty += (slot.requiredHeadcount - filled) * weights[slotIndex]
            }
        }

        let total = penalty + fairnessPenalty(chosen)
        let result = (penalty: total, chosen: chosen)
        chosen = saved
        return result
    }
}
