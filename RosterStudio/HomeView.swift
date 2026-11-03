import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.statusText)
                            .font(.headline)
                        if model.isDirty {
                            Text("员工或班次已修改，请重新排班。")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("本周概览") {
                    overviewRow("员工", "\(model.problem.employees.count) 人")
                    overviewRow("班次", "\(model.problem.slots.count) 个")
                    overviewRow("需求工时", "\(model.problem.requiredMinutes / 60) 小时")
                    overviewRow("已排工时", "\(filledMinutes / 60) 小时")
                    overviewRow("覆盖率", "\(coveragePercent)%")
                }
                Section {
                    Button {
                        model.solve()
                    } label: {
                        Label("重新排班", systemImage: "arrow.clockwise")
                    }
                    NavigationLink("查看完整排班") {
                        RosterListView()
                    }
                }
                Section("导出") {
                    exportRows
                }
            }
            .navigationTitle("排班工坊")
        }
    }

    @ViewBuilder
    private var exportRows: some View {
        if let ics = model.icsURL {
            ShareLink(item: ics) {
                Label("日历文件 (.ics)", systemImage: "calendar.badge.plus")
            }
        }
        if let csv = model.csvURL {
            ShareLink(item: csv) {
                Label("表格文件 (.csv)", systemImage: "tablecells")
            }
        }
        if model.icsURL == nil && model.csvURL == nil {
            Text("排班完成后可导出。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var filledMinutes: Int {
        guard let schedule = model.result?.schedule else { return 0 }
        let problem = model.problem
        return schedule.assignments.reduce(0) { total, assignment in
            total + (problem.slot(id: assignment.slotID)?.lengthMinutes ?? 0)
        }
    }

    private var coveragePercent: Int {
        let required = model.problem.requiredMinutes
        guard required > 0 else { return 0 }
        return Int((Double(filledMinutes) / Double(required)) * 100)
    }

    private func overviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
