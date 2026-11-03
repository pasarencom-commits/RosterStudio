import SwiftUI

struct TeamView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                ForEach($model.employees) { $employee in
                    NavigationLink {
                        EmployeeEditor(employee: $employee)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(employee.name)
                                .font(.headline)
                            Text(summary(for: employee))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if model.employees.isEmpty {
                    Text("还没有员工，点右上角添加。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("团队")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.addEmployee()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func summary(for employee: EmployeeDraft) -> String {
        var roles: [String] = []
        if employee.isBarista { roles.append("咖啡师") }
        if employee.isShiftLead { roles.append("值班经理") }
        let roleText = roles.isEmpty ? "未设置岗位" : roles.joined(separator: " · ")
        return "\(roleText) · 每周 \(employee.maximumWeeklyMinutes / 60) 小时"
    }
}

struct EmployeeEditor: View {
    @Binding var employee: EmployeeDraft

    private let days: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("姓名", text: $employee.name)
                Toggle("咖啡师", isOn: $employee.isBarista)
                Toggle("值班经理", isOn: $employee.isShiftLead)
            }
            Section("工时与休息") {
                Stepper(
                    "每周上限 \(employee.maximumWeeklyMinutes / 60) 小时",
                    value: $employee.maximumWeeklyMinutes,
                    in: 300...6_000,
                    step: 60
                )
                Stepper(
                    "最多连续 \(employee.maximumConsecutiveDays) 天",
                    value: $employee.maximumConsecutiveDays,
                    in: 1...7
                )
                Stepper(
                    "班次间休息 \(employee.minimumRestMinutes / 60) 小时",
                    value: $employee.minimumRestMinutes,
                    in: 0...1_440,
                    step: 30
                )
            }
            Section("可用时间") {
                ForEach(days, id: \.self) { day in
                    Toggle(isOn: dayBinding(day)) {
                        Text(day.fullName)
                    }
                }
                Stepper("每天从 \(employee.startHour):00 开始", value: $employee.startHour, in: 0...22)
                Stepper("每天到 \(employee.endHour):00 结束", value: $employee.endHour, in: 1...23)
            }
        }
        .navigationTitle(employee.name.isEmpty ? "员工" : employee.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { employee.availableDays.contains(day) },
            set: { isOn in
                var days = employee.availableDays
                if isOn {
                    days.insert(day)
                } else {
                    days.remove(day)
                }
                employee.availableDays = days
            }
        )
    }
}
