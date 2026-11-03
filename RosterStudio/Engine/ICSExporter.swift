import Foundation

/// Renders a schedule as an RFC 5545 iCalendar document.
///
/// `weekStart` must be the instant of Monday 00:00 in the time zone the roster
/// is written for; slots are then placed relative to it. `DTSTAMP` uses
/// `weekStart` rather than "now" so that exporting the same schedule twice
/// produces byte-identical output.
public enum ICSExporter {
    public static func calendar(
        for schedule: Schedule,
        problem: SchedulingProblem,
        weekStart: Date,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
    ) -> String {
        let slotsByID = Dictionary(
            problem.slots.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let employeesByID = Dictionary(
            problem.employees.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let formatter = makeFormatter()
        let stamp = formatter.string(from: weekStart)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var events: [(start: Date, slotID: String, employeeID: String, lines: [String])] = []
        for assignment in schedule.assignments {
            guard let slot = slotsByID[assignment.slotID],
                  let employee = employeesByID[assignment.employeeID],
                  let startDate = calendar.date(byAdding: .minute, value: slot.startMinute, to: weekStart),
                  let endDate = calendar.date(byAdding: .minute, value: slot.endMinute, to: weekStart)
            else { continue }

            let lines = [
                "BEGIN:VEVENT",
                "UID:\(escape("\(slot.id)-\(employee.id)@shiftlattice.local"))",
                "DTSTAMP:\(stamp)",
                "DTSTART:\(formatter.string(from: startDate))",
                "DTEND:\(formatter.string(from: endDate))",
                "SUMMARY:\(escape("\(slot.role.id) - \(employee.displayName)"))",
                "DESCRIPTION:\(escape("\(slot.id) \(slot.formatted) [\(employee.id)]"))",
                "END:VEVENT",
            ]
            events.append((start: startDate, slotID: slot.id, employeeID: employee.id, lines: lines))
        }

        events.sort { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.slotID != rhs.slotID { return lhs.slotID < rhs.slotID }
            return lhs.employeeID < rhs.employeeID
        }

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//ShiftLattice//ShiftLattice 0.1.0//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
        ]
        for event in events {
            lines.append(contentsOf: event.lines)
        }
        lines.append("END:VCALENDAR")

        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    private static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }

    private static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "\\": result += "\\\\"
            case ";": result += "\\;"
            case ",": result += "\\,"
            case "\n": result += "\\n"
            default: result.append(character)
            }
        }
        return result
    }

    /// RFC 5545 asks for lines of at most 75 octets; continuation lines start
    /// with a single space.
    private static func fold(_ line: String) -> String {
        guard line.utf8.count > 75 else { return line }
        var parts: [String] = []
        var current = ""
        var currentBytes = 0
        for character in line {
            let characterString = String(character)
            let characterBytes = characterString.utf8.count
            let limit = parts.isEmpty ? 75 : 74
            if currentBytes + characterBytes > limit {
                parts.append(current)
                current = " " + characterString
                currentBytes = 1 + characterBytes
            } else {
                current += characterString
                currentBytes += characterBytes
            }
        }
        parts.append(current)
        return parts.joined(separator: "\r\n")
    }
}
