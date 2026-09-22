import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: ProgressModel
    let showFloatingPanel: () -> Void
    let quit: () -> Void

    var body: some View {
        Form {
            Section("时间段") {
                DatePicker("开始", selection: Binding(get: { model.startDate }, set: { model.startDate = $0 }), displayedComponents: .hourAndMinute)
                DatePicker("结束", selection: Binding(get: { model.endDate }, set: { model.endDate = $0 }), displayedComponents: .hourAndMinute)
                Text(scheduleHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentScheduleState)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(scheduleStateColor)
            }

            Section("文案") {
                TextField("工作中", text: limitedBinding(for: \ProgressModel.centerLabel))
                    .textFieldStyle(.roundedBorder)
                ColorPicker(
                    "工作中文字颜色",
                    selection: Binding(
                        get: { model.centerLabelSwiftUIColor },
                        set: { model.setCenterLabelColor($0) }
                    ),
                    supportsOpacity: false
                )
                TextField("完成后", text: limitedBinding(for: \ProgressModel.completedLabel))
                    .textFieldStyle(.roundedBorder)
                ColorPicker(
                    "完成后文字颜色",
                    selection: Binding(
                        get: { model.completedLabelSwiftUIColor },
                        set: { model.setCompletedLabelColor($0) }
                    ),
                    supportsOpacity: false
                )
                Text("最多 6 个字符；留空时分别使用“牛马”和“下班”。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("圆形小组件") {
                Toggle("显示小组件", isOn: $model.showFloatingPanel)
                LabeledContent("尺寸") {
                    Slider(value: $model.circleSize, in: 40...88, step: 2)
                        .frame(width: 190)
                    Text("\(Int(model.circleSize))")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
                LabeledContent("透明度") {
                    Slider(value: $model.panelOpacity, in: 0.45...1, step: 0.05)
                        .frame(width: 190)
                }
                ColorPicker(
                    "核心背景",
                    selection: Binding(
                        get: { model.backgroundSwiftUIColor },
                        set: { model.setBackgroundColor($0) }
                    ),
                    supportsOpacity: false
                )
                LabeledContent("核心透明度") {
                    Slider(value: $model.backgroundOpacity, in: 0.15...1, step: 0.05)
                        .frame(width: 190)
                }
                ColorPicker(
                    "已完成进度",
                    selection: Binding(
                        get: { model.progressSwiftUIColor },
                        set: { model.setProgressColor($0) }
                    ),
                    supportsOpacity: false
                )
                LabeledContent("已完成透明度") {
                    Slider(value: $model.progressOpacity, in: 0.05...1, step: 0.05)
                        .frame(width: 190)
                }
                ColorPicker(
                    "未完成轨道",
                    selection: Binding(
                        get: { model.trackSwiftUIColor },
                        set: { model.setTrackColor($0) }
                    ),
                    supportsOpacity: false
                )
                LabeledContent("轨道透明度") {
                    Slider(value: $model.trackOpacity, in: 0.05...1, step: 0.05)
                        .frame(width: 190)
                }
                ColorPicker(
                    "定位点颜色",
                    selection: Binding(
                        get: { model.beaconSwiftUIColor },
                        set: { model.setBeaconColor($0) }
                    ),
                    supportsOpacity: false
                )
                LabeledContent("定位点直径") {
                    Slider(value: $model.beaconDiameter, in: 3...18, step: 1)
                        .frame(width: 190)
                    Text("\(Int(model.beaconDiameter))")
                        .monospacedDigit()
                        .frame(width: 20, alignment: .trailing)
                }
                HStack {
                    Spacer()
                    Button("恢复默认外观") {
                        model.resetAppearanceDefaults()
                    }
                }
            }

            Section("菜单栏") {
                Toggle("显示秒数", isOn: $model.showSeconds)
                Toggle("显示剩余时间", isOn: $model.showMenuBarRemaining)
            }

            HStack {
                Button("显示小组件", action: showFloatingPanel)
                Spacer()
                Button("退出牛马", role: .destructive, action: quit)
            }
        }
        .formStyle(.grouped)
        .padding(6)
        .frame(width: 460, height: 520)
    }

    private var scheduleHint: String {
        model.endMinutes <= model.startMinutes ? "结束时间早于开始时间，将按跨夜计划计算。" : "每天按此时间段自动计算，无需手动启动。"
    }

    private var currentScheduleState: String {
        let currentTime = model.now.formatted(date: .omitted, time: .shortened)
        switch model.snapshot.phase {
        case .waiting:
            return "当前 " + currentTime + "：尚未开始，" + model.statusText
        case .running:
            return "当前 " + currentTime + "：进行中，" + model.statusText
        case .finished:
            return "当前 " + currentTime + "：已超过结束时间，因此显示“下班”"
        }
    }

    private var scheduleStateColor: Color {
        switch model.snapshot.phase {
        case .waiting: .secondary
        case .running: model.progressSwiftUIColor
        case .finished: model.completedLabelSwiftUIColor
        }
    }

    private func limitedBinding(for keyPath: ReferenceWritableKeyPath<ProgressModel, String>) -> Binding<String> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = String($0.prefix(6)) }
        )
    }
}
