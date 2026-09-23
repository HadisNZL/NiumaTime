import SwiftUI

enum AppearanceContrast {
    static func ratio(_ firstRGB: Int, _ secondRGB: Int) -> Double {
        let first = luminance(firstRGB)
        let second = luminance(secondRGB)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    static func warning(
        backgroundRGB: Int,
        waitingRGB: Int,
        workingRGB: Int,
        completedRGB: Int,
        accentRGB: Int
    ) -> String? {
        let labels = [
            ("待命文字", waitingRGB),
            ("工作中文字", workingRGB),
            ("完成后文字", completedRGB)
        ]
        let lowContrastLabels = labels.compactMap { name, rgb in
            ratio(backgroundRGB, rgb) < 3 ? name : nil
        }
        if !lowContrastLabels.isEmpty {
            return lowContrastLabels.joined(separator: "、") + "与牛头底色对比偏低，可能看不清。"
        }
        if ratio(backgroundRGB, accentRGB) < 1.6 {
            return "牛角与面部点缀和牛头底色过于接近，轮廓可能不明显。"
        }
        return nil
    }

    private static func luminance(_ rgb: Int) -> Double {
        func linear(_ component: Int) -> Double {
            let value = Double(component) / 255
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((rgb >> 16) & 0xFF)
            + 0.7152 * linear((rgb >> 8) & 0xFF)
            + 0.0722 * linear(rgb & 0xFF)
    }
}

enum PreviewStateText {
    static func scheduleHint(startMinutes: Int, endMinutes: Int) -> String {
        if endMinutes == startMinutes {
            return "开始与结束相同，将按连续 24 小时的全天计划计算。"
        }
        if endMinutes < startMinutes {
            return "结束时间早于开始时间，将按跨夜计划计算。"
        }
        return "每天按此时间段自动计算，无需手动启动。"
    }

    static func description(for mood: CowMood, startMinutes: Int, endMinutes: Int) -> String {
        let duration = endMinutes > startMinutes
            ? endMinutes - startMinutes
            : 24 * 60 - startMinutes + endMinutes
        let nearDuration = min(5, duration)
        let nearStart = startMinutes + duration - nearDuration
        let timelineEnd = startMinutes + duration

        switch mood {
        case .resting:
            if endMinutes == startMinutes { return "等待 · 全天计划不单独出现" }
            if endMinutes < startMinutes { return "等待 · 跨夜计划不单独出现，班次外显示完成" }
            if startMinutes == 0 { return "等待 · 当前计划不单独出现" }
            return "等待 · 00:00–\(clock(startMinutes))"
        case .focused:
            guard duration > 5 else { return "工作 · 当前时段不超过 5 分钟，全程进入临近状态" }
            return "工作 · \(clock(startMinutes))–\(clock(nearStart))"
        case .expectant:
            return "临近 · \(clock(nearStart))–\(clock(timelineEnd))（结束前 \(nearDuration) 分钟）"
        case .relaxed:
            if endMinutes == startMinutes { return "完成 · 全天计划不单独出现" }
            if endMinutes < startMinutes { return "完成 · \(clock(endMinutes))–\(clock(startMinutes))" }
            return "完成 · \(clock(endMinutes)) 后至次日 00:00"
        }
    }

    private static func clock(_ timelineMinutes: Int) -> String {
        let normalized = ((timelineMinutes % (24 * 60)) + 24 * 60) % (24 * 60)
        let value = String(format: "%02d:%02d", normalized / 60, normalized % 60)
        return timelineMinutes >= 24 * 60 ? "次日 \(value)" : value
    }
}

struct SettingsView: View {
    private struct AccentPreset: Identifiable {
        let name: String
        let rgb: Int
        var id: Int { rgb }
    }

    private static let accentPresets = [
        AccentPreset(name: "橙红", rgb: 0xEC4300),
        AccentPreset(name: "深青", rgb: 0x0A7F84),
        AccentPreset(name: "石板蓝", rgb: 0x425A7A)
    ]

    @ObservedObject var model: ProgressModel
    @State private var previewMood: CowMood = .focused
    let showFloatingPanel: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Picker("表情预览", selection: $previewMood) {
                    Text("等待").tag(CowMood.resting)
                    Text("工作").tag(CowMood.focused)
                    Text("临近").tag(CowMood.expectant)
                    Text("完成").tag(CowMood.relaxed)
                }
                .pickerStyle(.segmented)

                FloatingProgressView(model: model, openSettings: {}, previewMood: previewMood)
                    .frame(width: model.effectivePanelSize.width, height: model.effectivePanelSize.height)
                    .opacity(model.panelOpacity)
                    .allowsHitTesting(false)
                    .transaction { $0.disablesAnimations = true }
                    .frame(maxWidth: .infinity)

                Text(previewStateDescription)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("耳朵数字为示例；预览不修改时间段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider()

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
                TextField("待命", text: limitedBinding(for: \ProgressModel.waitingLabel))
                    .textFieldStyle(.roundedBorder)
                ColorPicker(
                    "待命文字颜色",
                    selection: Binding(
                        get: { model.waitingLabelSwiftUIColor },
                        set: { model.setWaitingLabelColor($0) }
                    ),
                    supportsOpacity: false
                )
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
                Text("最多 6 个字符；留空时分别使用“待命”“牛马”和“下班”。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("悬浮小组件") {
                Toggle("显示小组件", isOn: $model.showFloatingPanel)
                Toggle("锁定当前位置", isOn: $model.lockPanelPosition)
                Toggle("显示牛耳朵", isOn: $model.showCowEars)
                Text("双耳显示时、分，悬停核心区显示秒；待命时耳朵平时显示开始时间，悬停后临时切换为剩余时、分。隐藏双耳时，一小时以上显示时、分，一小时内显示分、秒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("尺寸") {
                    Slider(value: $model.widgetSize, in: 40...88, step: 2)
                        .frame(width: 190)
                    Text("\(Int(model.widgetSize))")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
                LabeledContent("透明度") {
                    Slider(value: $model.panelOpacity, in: 0.45...1, step: 0.05)
                        .frame(width: 190)
                }
                ColorPicker(
                    "牛头底色",
                    selection: Binding(
                        get: { model.backgroundSwiftUIColor },
                        set: { model.setBackgroundColor($0) }
                    ),
                    supportsOpacity: false
                )
                VStack(alignment: .leading, spacing: 10) {
                    ColorPicker(
                        "牛角与面部点缀",
                        selection: Binding(
                            get: { model.accentSwiftUIColor },
                            set: { model.setAccentColor($0) }
                        ),
                        supportsOpacity: false
                    )
                    HStack(spacing: 8) {
                        Text("常用色")
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            ForEach(Self.accentPresets) { preset in
                                Button {
                                    model.accentRGB = preset.rgb
                                } label: {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(color(for: preset.rgb))
                                            .frame(width: 14, height: 14)
                                        Text(preset.name)
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold))
                                            .opacity(model.accentRGB == preset.rgb ? 1 : 0)
                                            .frame(width: 10)
                                    }
                                    .font(.caption)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .help(String(format: "#%06X", preset.rgb))
                            }
                        }
                    }
                }
                if let warning = appearanceContrastWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
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

            Section("启动") {
                Toggle(
                    "登录时自动启动",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLoginEnabled($0) }
                    )
                )
                if model.launchAtLoginNeedsApproval {
                    HStack {
                        Text("需要在系统设置的“登录项”中允许牛马。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("打开登录项设置") {
                            model.openLoginItemsSettings()
                        }
                    }
                }
                if let error = model.launchAtLoginError {
                    Text("设置失败：\(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("显示小组件", action: showFloatingPanel)
                Spacer()
                Text(AppVersion.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("退出牛马", role: .destructive, action: quit)
            }
        }
        .formStyle(.grouped)
        .padding(6)
        }
        .frame(width: 460, height: 600)
        .onAppear { model.refreshLaunchAtLoginStatus() }
    }

    private var scheduleHint: String {
        PreviewStateText.scheduleHint(
            startMinutes: model.startMinutes,
            endMinutes: model.endMinutes
        )
    }

    private var appearanceContrastWarning: String? {
        AppearanceContrast.warning(
            backgroundRGB: model.backgroundRGB,
            waitingRGB: model.waitingLabelRGB,
            workingRGB: model.centerLabelRGB,
            completedRGB: model.completedLabelRGB,
            accentRGB: model.accentRGB
        )
    }

    private var previewStateDescription: String {
        PreviewStateText.description(
            for: previewMood,
            startMinutes: model.startMinutes,
            endMinutes: model.endMinutes
        )
    }

    private var currentScheduleState: String {
        let currentTime = model.now.formatted(date: .omitted, time: .shortened)
        if model.isRestingToday {
            return "当前 " + currentTime + "：休息至 " + (model.restResumeText ?? "计划结束") + "，届时自动恢复"
        }
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
        if model.isRestingToday { return model.waitingLabelSwiftUIColor }
        return switch model.snapshot.phase {
        case .waiting: model.waitingLabelSwiftUIColor
        case .running: model.accentSwiftUIColor
        case .finished: model.completedLabelSwiftUIColor
        }
    }

    private func limitedBinding(for keyPath: ReferenceWritableKeyPath<ProgressModel, String>) -> Binding<String> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = String($0.prefix(6)) }
        )
    }

    private func color(for rgb: Int) -> Color {
        Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
