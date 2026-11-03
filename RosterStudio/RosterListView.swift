import SwiftUI

struct RosterListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            ForEach(Weekday.allCases, id: \.self) { day in
                if !slots(on: day).isEmpty {
                    Section {
                        ForEach(slots(on: day), id: \.id) { slot in
                            row(for: slot)
                        }
                    } header: {
                        Text(day.fullName)
                    }
                }
            }
            if model.problem.slots.isEmpty {
                Text("还没有班次，请到「班次」页添加。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("排班明细")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func slots(on day: Weekday) -> [ShiftSlot] {
        model.problem.slots
            .filter { $0.weekday == day }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private func row(for slot: ShiftSlot) -> some View {
        let assigned = assignees(for: slot)
        let title = "\(slot.formatted) · \(roleLabel(for: slot.role))"
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(assigned.count)/\(slot.requiredHeadcount) 人")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(assigned.isEmpty ? "未排到人" : assigned.joined(separator: "、"))
                .font(.footnote)
                .foregroundStyle(assigned.isEmpty ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
    }

    private func assignees(for slot: ShiftSlot) -> [String] {
        guard let schedule = model.result?.schedule else { return [] }
        let names = Dictionary(
            model.employees.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        return schedule.assignments
            .filter { $0.slotID == slot.id }
            .map { $0.employeeID }
            .sorted()
            .map { names[$0] ?? $0 }
    }

    private func roleLabel(for role: Role) -> String {
        role == shiftLeadRole ? "值班经理" : "咖啡师"
    }
}
