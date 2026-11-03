import Foundation

/// Renders a schedule as CSV for spreadsheets and payroll imports.
public enum CSVExporter {
    /// The header written before the rows.
    public static let header = "slot_id,role,weekday,start,end,employee_id,employee_name"

    public static func csv(for schedule: Schedule, problem: SchedulingProblem) -> String {
        let slotsByID = Dictionary(
            problem.slots.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let employeesByID = Dictionary(
            problem.employees.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var rows: [(start: Int, slotID: String, employeeID: String, cells: [String])] = []
        for assignment in schedule.assignments {
            guard let slot = slotsByID[assignment.slotID],
                  let employee = employeesByID[assignment.employeeID]
            else { continue }

            let start = WeekClock.clockLabel(slot.startMinute % WeekClock.minutesPerDay)
            let end = WeekClock.clockLabel(slot.endMinute % WeekClock.minutesPerDay)
            let cells = [
                slot.id,
                slot.role.id,
                slot.weekday?.shortName ?? "?",
                start,
                end,
                employee.id,
                employee.displayName,
            ]
            rows.append((start: slot.startMinute, slotID: slot.id, employeeID: employee.id, cells: cells))
        }

        rows.sort { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.slotID != rhs.slotID { return lhs.slotID < rhs.slotID }
            return lhs.employeeID < rhs.employeeID
        }

        var lines = [header]
        for row in rows {
            lines.append(row.cells.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ value: String) -> String {
        let needsQuoting = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
