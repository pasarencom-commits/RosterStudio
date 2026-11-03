import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                ForEach($model.templates) { $template in
                    NavigationLink {
                        TemplateEditor(template: $template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.headline)
                            Text(detail(for: template))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if model.templates.isEmpty {
                    Text("还没有班次，点右上角添加。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("班次模板")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.addTemplate()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func detail(for template: TemplateDraft) -> String {
        let role = template.isLead ? "值班经理" : "咖啡师"
        let dayCount = template.weekdays.count
        return "\(role) · \(template.startHour):00 起 \(template.lengthMinutes / 60) 小时 · \(dayCount) 天 · 每天 \(template.requiredHeadcount) 人"
    }
}

struct TemplateEditor: View {
    @Binding var template: TemplateDraft

    private let days: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]

    var body: some View {
        Form {
            Section("名称与岗位") {
                TextField("名称", text: $template.title)
                Toggle("值班经理岗位", isOn: $template.isLead)
            }
            Section("时间") {
                Stepper("开始 \(template.startHour):00", value: $template.startHour, in: 0...22)
                Stepper(
                    "时长 \(template.lengthMinutes / 60) 小时",
                    value: $template.lengthMinutes,
                    in: 60...720,
                    step: 60
                )
            }
            Section("人数与优先级") {
                Stepper(
                    "每天需要 \(template.requiredHeadcount) 人",
                    value: $template.requiredHeadcount,
                    in: 1...5
                )
                Stepper("优先级 \(template.priority)", value: $template.priority, in: 1...5)
            }
            Section("星期") {
                ForEach(days, id: \.self) { day in
                    Toggle(isOn: dayBinding(day)) {
                        Text(day.fullName)
                    }
                }
            }
        }
        .navigationTitle(template.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { template.weekdays.contains(day) },
            set: { isOn in
                var days = template.weekdays
                if isOn {
                    days.insert(day)
                } else {
                    days.remove(day)
                }
                template.weekdays = days
            }
        )
    }
}
