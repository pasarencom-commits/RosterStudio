import Combine
import Foundation

// MARK: - Roles

let baristaRole = Role("barista")
let shiftLeadRole = Role("shift-lead")

// MARK: - Drafts

/// Editable form of an `Employee`. The engine type is immutable, so the UI keeps
/// drafts and rebuilds the scheduling problem on demand.
struct EmployeeDraft: Identifiable, Hashable {
    let id: String
    var name: String
    var isBarista: Bool
    var isShiftLead: Bool
    var availableDays: Set<Weekday>
    var startHour: Int
    var endHour: Int
    var maximumWeeklyMinutes: Int
    var maximumDailyMinutes: Int?
    var minimumRestMinutes: Int
    var maximumConsecutiveDays: Int
    var preferredSlotIDs: Set<String>
    var avoidedSlotIDs: Set<String>

    var roles: Set<Role> {
        var roles: Set<Role> = []
        if isBarista { roles.insert(baristaRole) }
        if isShiftLead { roles.insert(shiftLeadRole) }
        return roles
    }

    var employee: Employee {
        let days = availableDays.sorted { $0.rawValue < $1.rawValue }
        let availability = days.map { day in
            MinuteRange(
                start: WeekClock.minute(day: day, hour: startHour),
                end: WeekClock.minute(day: day, hour: endHour)
            )
        }
        return Employee(
            id: id,
            name: name,
            roles: roles,
            availability: availability,
            unavailability: [],
            maximumWeeklyMinutes: maximumWeeklyMinutes,
            maximumDailyMinutes: maximumDailyMinutes,
            minimumRestMinutes: minimumRestMinutes,
            maximumConsecutiveDays: maximumConsecutiveDays,
            preferredSlotIDs: preferredSlotIDs,
            avoidedSlotIDs: avoidedSlotIDs
        )
    }
}

/// Editable form of a repeating shift pattern (`ShiftTemplate`).
struct TemplateDraft: Identifiable, Hashable {
    let id: String
    var title: String
    var isLead: Bool
    var weekdays: Set<Weekday>
    var startHour: Int
    var lengthMinutes: Int
    var requiredHeadcount: Int
    var priority: Int

    var role: Role {
        isLead ? shiftLeadRole : baristaRole
    }

    var template: ShiftTemplate {
        ShiftTemplate(
            idPrefix: id,
            role: role,
            weekdays: weekdays,
            startMinuteOfDay: startHour * 60,
            lengthMinutes: lengthMinutes,
            requiredHeadcount: requiredHeadcount,
            priority: priority
        )
    }
}

// MARK: - Sample data

enum SampleData {
    static let weekdaysOnly: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let everyDay: Set<Weekday> = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]

    static let employees: [EmployeeDraft] = [
        EmployeeDraft(
            id: "ana",
            name: "阿楠",
            isBarista: true,
            isShiftLead: false,
            availableDays: everyDay,
            startHour: 8,
            endHour: 20,
            maximumWeeklyMinutes: 2_400,
            maximumDailyMinutes: nil,
            minimumRestMinutes: 600,
            maximumConsecutiveDays: 5,
            preferredSlotIDs: ["open-d0-m480", "open-d2-m480"],
            avoidedSlotIDs: []
        ),
        EmployeeDraft(
            id: "bo",
            name: "阿波",
            isBarista: true,
            isShiftLead: true,
            availableDays: everyDay,
            startHour: 8,
            endHour: 20,
            maximumWeeklyMinutes: 2_400,
            maximumDailyMinutes: nil,
            minimumRestMinutes: 600,
            maximumConsecutiveDays: 5,
            preferredSlotIDs: [],
            avoidedSlotIDs: []
        ),
        EmployeeDraft(
            id: "chen",
            name: "小辰",
            isBarista: true,
            isShiftLead: false,
            availableDays: weekdaysOnly,
            startHour: 9,
            endHour: 20,
            maximumWeeklyMinutes: 1_800,
            maximumDailyMinutes: 600,
            minimumRestMinutes: 660,
            maximumConsecutiveDays: 4,
            preferredSlotIDs: [],
            avoidedSlotIDs: ["close-d4-m780"]
        ),
    ]

    static let templates: [TemplateDraft] = [
        TemplateDraft(
            id: "open",
            title: "早班",
            isLead: false,
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
            startHour: 8,
            lengthMinutes: 300,
            requiredHeadcount: 1,
            priority: 2
        ),
        TemplateDraft(
            id: "close",
            title: "晚班",
            isLead: false,
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
            startHour: 13,
            lengthMinutes: 300,
            requiredHeadcount: 1,
            priority: 1
        ),
        TemplateDraft(
            id: "lead",
            title: "值班经理",
            isLead: true,
            weekdays: weekdaysOnly,
            startHour: 9,
            lengthMinutes: 480,
            requiredHeadcount: 1,
            priority: 3
        ),
    ]

    static func newEmployee(index: Int) -> EmployeeDraft {
        EmployeeDraft(
            id: "employee-\(index)",
            name: "新员工 \(index)",
            isBarista: true,
            isShiftLead: false,
            availableDays: weekdaysOnly,
            startHour: 9,
            endHour: 18,
            maximumWeeklyMinutes: 2_400,
            maximumDailyMinutes: nil,
            minimumRestMinutes: 600,
            maximumConsecutiveDays: 5,
            preferredSlotIDs: [],
            avoidedSlotIDs: []
        )
    }
}

// MARK: - App model

final class AppModel: ObservableObject {
    @Published var employees: [EmployeeDraft] = SampleData.employees
    @Published var templates: [TemplateDraft] = SampleData.templates
    @Published private(set) var result: SolveResult?
    @Published private(set) var icsURL: URL?
    @Published private(set) var csvURL: URL?
    @Published var statusText = "点按「重新排班」生成本周排班"
    @Published var isDirty = false

    let weekStart = AppModel.mondayOfCurrentWeek()

    var problem: SchedulingProblem {
        SchedulingProblem(
            employees: employees.map { $0.employee },
            slots: templates.flatMap { $0.template.slots() }
        )
    }

    func addEmployee() {
        employees.append(SampleData.newEmployee(index: employees.count + 1))
        isDirty = true
    }

    func addTemplate() {
        let index = templates.count + 1
        templates.append(
            TemplateDraft(
                id: "shift-\(index)",
                title: "新班次 \(index)",
                isLead: false,
                weekdays: SampleData.weekdaysOnly,
                startHour: 9,
                lengthMinutes: 240,
                requiredHeadcount: 1,
                priority: 1
            )
        )
        isDirty = true
    }

    func solve() {
        let current = problem
        let solved = SchedulingEngine.solve(
            current,
            options: SolveOptions(maximumSteps: 120_000, allowUnfilled: true, fairnessWeight: 1)
        )
        result = solved
        switch solved {
        case .optimal(let schedule, let report):
            if report.fullyCovered {
                statusText = "最优排班 · 全部班次已覆盖"
            } else {
                statusText = "最优排班 · 仍空缺 \(report.uncoveredUnits) 个班次单位"
            }
            writeExports(schedule: schedule, problem: current)
        case .bestEffort(let schedule, let report):
            statusText = "搜索预算用尽 · 仍空缺 \(report.uncoveredUnits) 个班次单位"
            writeExports(schedule: schedule, problem: current)
        case .infeasible(let report):
            if let certificate = report.certificates.first {
                statusText = "无解 · \(certificate.description)"
            } else {
                statusText = "无解 · 现有约束下无法覆盖全部班次"
            }
        case .invalid(let issues):
            statusText = "配置有误 · \(issues.first?.message ?? "请检查员工与班次设置")"
        }
        isDirty = false
    }

    private func writeExports(schedule: Schedule, problem: SchedulingProblem) {
        let calendar = ICSExporter.calendar(
            for: schedule,
            problem: problem,
            weekStart: weekStart,
            timeZone: .current
        )
        let table = CSVExporter.csv(for: schedule, problem: problem)
        let directory = FileManager.default.temporaryDirectory
        let ics = directory.appendingPathComponent("roster.ics")
        let csv = directory.appendingPathComponent("roster.csv")
        do {
            try calendar.write(to: ics, atomically: true, encoding: .utf8)
            try table.write(to: csv, atomically: true, encoding: .utf8)
            icsURL = ics
            csvURL = csv
        } catch {
            icsURL = nil
            csvURL = nil
        }
    }

    static func mondayOfCurrentWeek() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: today) ?? today
    }
}
