import SwiftUI
import AppKit

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
            if endMinutes == startMinutes { return "待命 · 全天计划不单独出现" }
            if endMinutes < startMinutes {
                let standbyStart = Schedule.overnightStandbyStartMinutes(
                    startMinutes: startMinutes,
                    endMinutes: endMinutes
                )
                return "待命 · \(clock(standbyStart))–\(clock(startMinutes))"
            }
            if startMinutes == 0 { return "待命 · 当前计划不单独出现" }
            return "待命 · 00:00–\(clock(startMinutes))"
        case .focused:
            guard duration > 5 else { return "工作 · 当前时段不超过 5 分钟，全程进入临近状态" }
            return "工作 · \(clock(startMinutes))–\(clock(nearStart))"
        case .expectant:
            return "临近 · \(clock(nearStart))–\(clock(timelineEnd))（结束前 \(nearDuration) 分钟）"
        case .relaxed:
            if endMinutes == startMinutes { return "完成 · 全天计划不单独出现" }
            if endMinutes < startMinutes {
                let standbyStart = Schedule.overnightStandbyStartMinutes(
                    startMinutes: startMinutes,
                    endMinutes: endMinutes
                )
                return "完成 · \(clock(endMinutes))–\(clock(standbyStart))"
            }
            return "完成 · \(clock(endMinutes)) 后至次日 00:00"
        }
    }

    private static func clock(_ timelineMinutes: Int) -> String {
        let normalized = ((timelineMinutes % (24 * 60)) + 24 * 60) % (24 * 60)
        let value = String(format: "%02d:%02d", normalized / 60, normalized % 60)
        return timelineMinutes >= 24 * 60 ? "次日 \(value)" : value
    }
}

private struct StableSwitchToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.18))
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        .shadow(color: .black.opacity(0.16), radius: 0.7, y: 0.5)
                }
                .frame(width: switchWidth, height: switchHeight)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.48)
    }

    private var switchWidth: CGFloat {
        controlSize == .small || controlSize == .mini ? 28 : 32
    }

    private var switchHeight: CGFloat {
        controlSize == .small || controlSize == .mini ? 16 : 18
    }
}

struct SettingsView: View {
    private struct AccentPreset: Identifiable {
        let name: String
        let rgb: Int
        var id: Int { rgb }
    }

    private static let accentPresets = [
        AccentPreset(name: "默认紫", rgb: 0x5856D6),
        AccentPreset(name: "橙红", rgb: 0xEC4300),
        AccentPreset(name: "深青", rgb: 0x0A7F84)
    ]

    private static let calendarAccentPresets = [
        AccentPreset(name: "默认紫", rgb: 0x5856D6),
        AccentPreset(name: "日历蓝", rgb: 0x2563EB),
        AccentPreset(name: "深青", rgb: 0x0A7F84)
    ]

    @ObservedObject var model: ProgressModel
    @State private var previewMood: CowMood = .focused
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("设置分类", selection: $model.settingsTab) {
                Label("牛马日历", systemImage: "calendar").tag(SettingsTab.calendar)
                Label("牛马倒计时", systemImage: "timer").tag(SettingsTab.countdown)
                Label("关于与更新", systemImage: "info.circle").tag(SettingsTab.about)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            switch model.settingsTab {
            case .calendar:
                calendarSettings
            case .countdown:
                countdownSettings
            case .about:
                AboutAndUpdateSettings()
            }

            Divider()
            commonSettings
        }
        .frame(width: 460, height: 620)
        .toggleStyle(StableSwitchToggleStyle())
        .onAppear { model.refreshLaunchAtLoginStatus() }
    }

    private var countdownSettings: some View {
        VStack(spacing: 0) {
            Toggle("开启牛马倒计时", isOn: $model.countdownEnabled)
                .font(.body.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            if model.countdownEnabled {
                Divider()

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("表情预览")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(currentStateLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(currentStateColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(currentStateColor.opacity(0.10), in: Capsule())
                }

                HStack {
                    Spacer(minLength: 0)
                    Picker("表情预览", selection: $previewMood) {
                        Text("待命").tag(CowMood.resting)
                        Text("工作").tag(CowMood.focused)
                        Text("临近").tag(CowMood.expectant)
                        Text("完成").tag(CowMood.relaxed)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 330)
                    Spacer(minLength: 0)
                }

                FloatingProgressView(model: model, openSettings: {}, previewMood: previewMood)
                    .frame(width: model.effectivePanelSize.width, height: model.effectivePanelSize.height)
                    .opacity(model.panelOpacity)
                    .allowsHitTesting(false)
                    .transaction { $0.disablesAnimations = true }
                    .frame(maxWidth: .infinity)

                Text(previewStateDescription)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(previewStateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider()

        Form {
            Section("时间段") {
                DatePicker("开始", selection: Binding(get: { model.startDate }, set: { model.startDate = $0 }), displayedComponents: .hourAndMinute)
                DatePicker("结束", selection: Binding(get: { model.endDate }, set: { model.endDate = $0 }), displayedComponents: .hourAndMinute)
            }

            Section("牛马悬浮") {
                Toggle("锁定牛马悬浮位置", isOn: $model.lockPanelPosition)
                Toggle("显示牛耳朵", isOn: $model.showCowEars)
                Text("双耳显示时、分，悬停核心区显示秒；待命时耳朵平时显示开始时间，悬停后临时切换为剩余时、分。隐藏双耳时，一小时以上显示时、分，一小时内显示分、秒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("文案显示") {
                HStack(spacing: 10) {
                    Text("待命")
                        .frame(width: 48, alignment: .leading)
                    TextField("", text: limitedBinding(for: \ProgressModel.waitingLabel), prompt: Text("待命"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .accessibilityLabel("待命文案")
                    ColorPicker(
                        "待命文字颜色",
                        selection: Binding(
                            get: { model.waitingLabelSwiftUIColor },
                            set: { model.setWaitingLabelColor($0) }
                        ),
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .help("待命文字颜色")
                }
                HStack(spacing: 10) {
                    Text("工作中")
                        .frame(width: 48, alignment: .leading)
                    TextField("", text: limitedBinding(for: \ProgressModel.centerLabel), prompt: Text("牛马"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .accessibilityLabel("工作中文案")
                    ColorPicker(
                        "工作中文字颜色",
                        selection: Binding(
                            get: { model.centerLabelSwiftUIColor },
                            set: { model.setCenterLabelColor($0) }
                        ),
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .help("工作中文字颜色")
                }
                HStack(spacing: 10) {
                    Text("完成后")
                        .frame(width: 48, alignment: .leading)
                    TextField("", text: limitedBinding(for: \ProgressModel.completedLabel), prompt: Text("下班"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .accessibilityLabel("完成后文案")
                    ColorPicker(
                        "完成后文字颜色",
                        selection: Binding(
                            get: { model.completedLabelSwiftUIColor },
                            set: { model.setCompletedLabelColor($0) }
                        ),
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .help("完成后文字颜色")
                }
                Text("每项最多 6 个字符，留空时使用默认文案。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("恢复默认文案") {
                        model.resetTextDefaults()
                    }
                }
            }

            Section("外观与颜色") {
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

            Section("菜单栏倒计时") {
                Toggle("在日期图标旁显示倒计时", isOn: $model.showMenuBarRemaining)
                Toggle("显示秒数", isOn: $model.showSeconds)
                    .disabled(!model.showMenuBarRemaining)
                Text("仅控制屏幕顶部菜单栏，不影响牛马悬浮；最后一分钟仍按秒倒计时。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .padding(6)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var calendarSettings: some View {
        Form {
            Section("月历显示") {
                Picker("每周开始于", selection: $model.calendarFirstWeekday) {
                    Text("周一").tag(2)
                    Text("周日").tag(1)
                }
                .pickerStyle(.segmented)
                Toggle("显示农历", isOn: $model.showLunarDetails)
                Toggle("显示班休标记", isOn: $model.showWorkdayBadges)
                Toggle("显示月度统计", isOn: $model.showMonthSummary)
                Text("节日和节气始终显示；关闭农历后，普通日期仅保留公历数字。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("恢复日历默认设置") {
                        model.resetCalendarDisplayDefaults()
                    }
                }
            }

            Section("日历主题色") {
                ColorPicker(
                    "非假期强调色",
                    selection: Binding(
                        get: { model.calendarAccentSwiftUIColor },
                        set: { model.setCalendarAccentColor($0) }
                    ),
                    supportsOpacity: false
                )
                HStack(spacing: 8) {
                    Text("常用色")
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        ForEach(Self.calendarAccentPresets) { preset in
                            Button {
                                model.calendarAccentRGB = preset.rgb
                            } label: {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(color(for: preset.rgb))
                                        .frame(width: 14, height: 14)
                                    Text(preset.name)
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .opacity(model.calendarAccentRGB == preset.rgb ? 1 : 0)
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
                Text("调整今天、选中日期、节气及工作日信息；节假日和班休标记颜色保持不变。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .padding(6)
    }

    private var commonSettings: some View {
        VStack(spacing: 9) {
            launchAtLoginStatus
            settingsFooter
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var launchAtLoginStatus: some View {
        if model.launchAtLoginNeedsApproval {
            HStack {
                Text("需要在系统设置的“登录项”中允许牛马日历。")
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

    private var settingsFooter: some View {
        HStack {
            Toggle(
                "登录时打开",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                )
            )
            .controlSize(.small)
            .fixedSize()
            Spacer()
            Button("退出牛马日历", role: .destructive, action: quit)
        }
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

    private var previewStateColor: Color {
        switch previewMood {
        case .resting:
            model.waitingLabelSwiftUIColor
        case .focused:
            model.centerLabelSwiftUIColor
        case .expectant:
            model.centerLabelSwiftUIColor
        case .relaxed:
            model.completedLabelSwiftUIColor
        }
    }

    private var currentStateLabel: String {
        if model.isRestingToday { return "当前：今日休息" }
        return switch model.cowMood {
        case .resting: "当前：待命"
        case .focused: "当前：工作中"
        case .expectant: "当前：临近下班"
        case .relaxed: "当前：已完成"
        }
    }

    private var currentStateColor: Color {
        switch model.cowMood {
        case .resting:
            model.waitingLabelSwiftUIColor
        case .focused:
            model.centerLabelSwiftUIColor
        case .expectant:
            model.centerLabelSwiftUIColor
        case .relaxed:
            model.completedLabelSwiftUIColor
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

private struct AboutAndUpdateSettings: View {
    private static let appIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    private enum UpdateState {
        case idle
        case checking
        case current(String)
        case available(AppRelease)
        case failed(String)
    }

    @State private var updateState: UpdateState = .idle
    @State private var updateTask: Task<Void, Never>?
    @State private var downloadTask: Task<Void, Never>?
    @State private var downloadedUpdateURL: URL?
    @State private var downloadError: String?

    var body: some View {
        Form {
            Section {
                VStack(spacing: 9) {
                    Image(nsImage: Self.appIcon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 76, height: 76)
                        .accessibilityLabel("牛马日历应用图标")

                    Text("牛马日历")
                        .font(.title2.weight(.bold))
                    Text("通用日历与牛形上下班倒计时")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                LabeledContent("当前版本", value: AppVersion.value)
                LabeledContent(
                    "中国调休数据",
                    value: "\(ChinaWorkdayCalendar.supportedYears.lowerBound)–\(ChinaWorkdayCalendar.supportedYears.upperBound) 年"
                )

                HStack {
                    updateMessage
                    Spacer(minLength: 12)
                    Button {
                        checkForUpdates()
                    } label: {
                        if case .checking = updateState {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 54)
                        } else {
                            Text("检查更新")
                        }
                    }
                    .disabled(isChecking)
                }

                if case let .available(release) = updateState {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(release.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            if let downloadedUpdateURL {
                                Button("在 Finder 中显示") {
                                    NSWorkspace.shared.activateFileViewerSelecting([downloadedUpdateURL])
                                }
                            } else if release.canDownloadSecurely {
                                Button {
                                    download(release)
                                } label: {
                                    if isDownloading {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text("正在下载…")
                                        }
                                    } else {
                                        Text("下载更新")
                                    }
                                }
                                .disabled(isDownloading)
                            } else {
                                Button("打开发布页") {
                                    NSWorkspace.shared.open(release.pageURL)
                                }
                            }
                        }

                        if downloadedUpdateURL != nil {
                            Text("安装包已校验并保存到“下载”。退出当前版本后，解压并拖入“应用程序”替换即可。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let downloadError {
                            Text(downloadError)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("版本与更新")
            } footer: {
                Text("仅在手动检查或下载时访问 GitHub，不会后台联网，也不会自动替换当前应用。")
            }

            Section("项目") {
                Link(destination: AppUpdateChecker.projectURL) {
                    LabeledContent("开源项目") {
                        Label("GitHub", systemImage: "arrow.up.right.square")
                    }
                }
                Link(destination: AppUpdateChecker.releasesURL) {
                    LabeledContent("历史版本") {
                        Label("Releases", systemImage: "arrow.up.right.square")
                    }
                }
            }

            Section {
                Text("© 2026 牛马日历")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
        .padding(6)
        .onDisappear {
            updateTask?.cancel()
            updateTask = nil
            downloadTask?.cancel()
            downloadTask = nil
        }
    }

    @ViewBuilder
    private var updateMessage: some View {
        switch updateState {
        case .idle:
            Text("手动检查最新版本")
                .foregroundStyle(.secondary)
        case .checking:
            Text("正在检查…")
                .foregroundStyle(.secondary)
        case let .current(version):
            Label("已是最新版本（\(version)）", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .available(release):
            Label("发现新版本 \(release.version)", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
    }

    private var isChecking: Bool {
        if case .checking = updateState { return true }
        return false
    }

    private var isDownloading: Bool {
        downloadTask != nil
    }

    private func checkForUpdates() {
        updateTask?.cancel()
        downloadTask?.cancel()
        downloadTask = nil
        downloadedUpdateURL = nil
        downloadError = nil
        updateState = .checking
        updateTask = Task {
            do {
                let release = try await AppUpdateChecker.latestRelease()
                guard !Task.isCancelled else { return }
                updateState = AppVersionComparison.isNewer(release.version, than: AppVersion.short)
                    ? .available(release)
                    : .current(release.version)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                updateState = .failed(error.localizedDescription)
            }
        }
    }

    private func download(_ release: AppRelease) {
        downloadTask?.cancel()
        downloadError = nil
        downloadedUpdateURL = nil
        downloadTask = Task {
            do {
                let url = try await AppUpdateChecker.download(release)
                guard !Task.isCancelled else { return }
                downloadedUpdateURL = url
                downloadTask = nil
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch is CancellationError {
                downloadTask = nil
            } catch {
                guard !Task.isCancelled else { return }
                downloadError = error.localizedDescription
                downloadTask = nil
            }
        }
    }
}
