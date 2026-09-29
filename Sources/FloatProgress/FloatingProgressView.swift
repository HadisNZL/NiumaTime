import SwiftUI

struct FloatingProgressView: View {
    private enum EchoPhase: CaseIterable {
        case idle
        case crest
        case dissolve
    }

    private enum EarPulsePhase: CaseIterable {
        case idle
        case enlarge
        case settle
    }

    @ObservedObject var model: ProgressModel
    let openSettings: () -> Void
    var previewMood: CowMood? = nil
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var isHoveringCore = false

    var body: some View {
        GeometryReader { proxy in
            let side = CGFloat(model.widgetSize)
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2
            let mood = previewMood ?? model.cowMood

            ZStack {
                cowSilhouette(side: side, mood: mood)
                    .position(x: centerX, y: centerY)

                centerContent
                    .frame(width: side * (side <= 52 ? 0.60 : 0.56), height: side * 0.56)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        guard previewMood == nil else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) {
                            isHoveringCore = hovering
                        }
                        model.setCoreHovered(hovering)
                    }
                    .position(x: centerX, y: centerY)

                if model.showCowEars, let earTime = displayedEarTime {
                    earLabel(earTime.hours, side: side)
                        .position(x: centerX - side * CowLayout.earCenterOffset, y: centerY - side * 0.18 + earShift(for: mood, side: side))
                    earLabel(earTime.minutes, side: side)
                        .position(x: centerX + side * CowLayout.earCenterOffset, y: centerY - side * 0.18 + earShift(for: mood, side: side))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(previewMood == nil && !reduceMotion ? .easeInOut(duration: 0.26) : nil, value: mood)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: openSettings)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewMood == nil ? "\(displayText)，\(model.statusText)" : displayText)
    }

    private func cowSilhouette(side: CGFloat, mood: CowMood) -> some View {
        let width = CowLayout.panelWidth(for: side, showsEars: model.showCowEars)
        let optics = CowOptics.values(for: side)
        let base = model.backgroundSwiftUIColor
        let accent = model.accentSwiftUIColor
        let increasedContrast = colorSchemeContrast == .increased
        let outline = accent.opacity(increasedContrast ? 0.94 : 0.68)
        let outlineScale: CGFloat = increasedContrast ? 1.22 : 1
        let earY = side * 0.32 + earShift(for: mood, side: side)

        return ZStack {
            CowHornShape()
                .fill(accent.opacity(increasedContrast ? 1 : 0.82))
                .frame(width: side * optics.hornSize, height: side * optics.hornSize)
                .position(x: width / 2 - side * optics.hornX, y: side * 0.18)
            CowHornShape()
                .fill(accent.opacity(increasedContrast ? 1 : 0.82))
                .frame(width: side * optics.hornSize, height: side * optics.hornSize)
                .scaleEffect(x: -1, y: 1)
                .position(x: width / 2 + side * optics.hornX, y: side * 0.18)

            if model.showCowEars {
                CowEarShape()
                    .fill(base)
                    .overlay(CowEarShape().stroke(outline, lineWidth: max(side * optics.outlineRatio * outlineScale, 1.1)))
                    .frame(width: side * CowLayout.earWidth, height: side * 0.27)
                    .position(x: width / 2 - side * CowLayout.earCenterOffset, y: earY)
                CowEarShape()
                    .fill(base)
                    .overlay(CowEarShape().stroke(outline, lineWidth: max(side * optics.outlineRatio * outlineScale, 1.1)))
                    .frame(width: side * CowLayout.earWidth, height: side * 0.27)
                    .scaleEffect(x: -1, y: 1)
                    .position(x: width / 2 + side * CowLayout.earCenterOffset, y: earY)
                CowEarShape()
                    .fill(accent.opacity(increasedContrast ? 0.25 : 0.12))
                    .frame(width: side * 0.38, height: side * 0.16)
                    .position(x: width / 2 - side * 0.60, y: earY)
                CowEarShape()
                    .fill(accent.opacity(increasedContrast ? 0.25 : 0.12))
                    .frame(width: side * 0.38, height: side * 0.16)
                    .scaleEffect(x: -1, y: 1)
                    .position(x: width / 2 + side * 0.60, y: earY)
            }

            CowHeadShape()
                .fill(base)
                .overlay(
                    CowHeadShape()
                        .stroke(
                            outline.opacity(increasedContrast ? 1 : 0.70),
                            lineWidth: max(side * optics.outlineRatio * 0.80 * outlineScale, 0.9)
                        )
                )
                .frame(width: side * optics.headWidth, height: side * optics.headHeight)
                .position(x: width / 2, y: side * optics.headCenterY)

            CowForeheadPatchShape()
                .fill(accent.opacity(increasedContrast ? 0.54 : 0.34))
                .frame(width: side * optics.patchWidth, height: side * optics.patchHeight)
                .position(x: width / 2 - side * 0.205, y: side * 0.235)

            eye(side: side, optics: optics, mood: mood, isLeft: true, color: accent)
                .position(x: width / 2 - side * optics.eyeX, y: eyeY(for: mood, side: side))
            eye(side: side, optics: optics, mood: mood, isLeft: false, color: accent)
                .position(x: width / 2 + side * optics.eyeX, y: eyeY(for: mood, side: side))

            Ellipse()
                .fill(accent.opacity(increasedContrast ? 0.42 : 0.24))
                .frame(width: side * optics.muzzleWidth, height: side * optics.muzzleHeight)
                .position(x: width / 2, y: side * optics.muzzleY)
            Circle()
                .fill(accent.opacity(increasedContrast ? 1 : 0.80))
                .frame(width: pixelAligned(max(side * optics.nostrilDiameter, 2)), height: pixelAligned(max(side * optics.nostrilDiameter, 2)))
                .position(x: width / 2 - side * optics.nostrilX, y: side * optics.muzzleY)
            Circle()
                .fill(accent.opacity(increasedContrast ? 1 : 0.80))
                .frame(width: pixelAligned(max(side * optics.nostrilDiameter, 2)), height: pixelAligned(max(side * optics.nostrilDiameter, 2)))
                .position(x: width / 2 + side * optics.nostrilX, y: side * optics.muzzleY)
        }
        .frame(width: width, height: side)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func eye(side: CGFloat, optics: CowOptics, mood: CowMood, isLeft: Bool, color: Color) -> some View {
        let expressionWidth = side * optics.expressionWidth
        let contrastScale: CGFloat = colorSchemeContrast == .increased ? 1.18 : 1
        let featureOpacity = colorSchemeContrast == .increased ? 1.0 : 0.9
        let expressionStroke = pixelAligned(max(side * optics.expressionStrokeRatio * contrastScale, 1.3))
        if mood == .resting {
            CowSleepyEyeShape()
                .stroke(color.opacity(colorSchemeContrast == .increased ? 1 : 0.82), style: StrokeStyle(lineWidth: expressionStroke, lineCap: .round))
                .frame(width: expressionWidth, height: side * 0.065)
                .transition(.opacity)
        } else if mood == .expectant {
            if isLeft {
                CowWinkEyeShape()
                    .stroke(color.opacity(featureOpacity), style: StrokeStyle(lineWidth: expressionStroke, lineCap: .round))
                    .frame(width: expressionWidth, height: side * 0.065)
                    .transition(.opacity)
            } else {
                Circle()
                    .fill(color.opacity(featureOpacity))
                    .frame(width: pixelAligned(max(side * 0.09, 3.6)), height: pixelAligned(max(side * 0.09, 3.6)))
                    .transition(.opacity)
            }
        } else if mood == .relaxed {
            CowHappyEyeShape()
                .stroke(color.opacity(featureOpacity), style: StrokeStyle(lineWidth: expressionStroke, lineCap: .round))
                .frame(width: expressionWidth, height: side * 0.08)
                .transition(.opacity)
        } else {
            let diameter = pixelAligned(max(side * optics.focusedEyeDiameter, 3))
            Circle()
                .fill(color.opacity(colorSchemeContrast == .increased ? 1 : 0.88))
                .frame(width: diameter, height: diameter)
                .transition(.opacity)
        }
    }

    private func eyeY(for mood: CowMood, side: CGFloat) -> CGFloat {
        switch mood {
        case .resting: side * 0.34
        case .focused, .relaxed: side * 0.32
        case .expectant: side * 0.285
        }
    }

    private func earShift(for mood: CowMood, side: CGFloat) -> CGFloat {
        switch mood {
        case .resting: side * 0.030
        case .focused: 0
        case .expectant: -side * 0.050
        case .relaxed: side * 0.020
        }
    }

    @ViewBuilder
    private func earLabel(_ value: String, side: CGFloat) -> some View {
        let optics = CowOptics.values(for: side)
        let label = Text(value)
            .font(.system(size: max(side * optics.earLabelRatio, 7), weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(previewMood == .resting || (previewMood == nil && model.snapshot.phase == .waiting) ? model.waitingLabelSwiftUIColor : model.centerLabelSwiftUIColor)
            .fixedSize()
        if previewMood == nil && !reduceMotion {
            label
                .phaseAnimator(EarPulsePhase.allCases, trigger: value) { content, phase in
                    content.scaleEffect(phase == .enlarge ? 1.16 : 1)
                } animation: { phase in
                    phase == .enlarge
                        ? .easeOut(duration: 0.12)
                        : .spring(response: 0.23, dampingFraction: 0.82)
                }
                .accessibilityHidden(true)
        } else {
            label.accessibilityHidden(true)
        }
    }

    private var centerContent: some View {
        ZStack {
            if let seconds = displayedFinalMinuteSeconds {
                finalMinuteContent(seconds)
            } else {
                baseCenterLabel
                    .opacity(showHoverTime ? 0 : 1)

                if previewMood == nil {
                    hoverStatus
                        .opacity(showHoverTime ? 1 : 0)
                        .scaleEffect(showHoverTime ? 1 : 0.94)
                }
            }
        }
        .animation(previewMood == nil && !reduceMotion ? .easeOut(duration: 0.22) : nil, value: model.snapshot.phase)
        .animation(previewMood == nil && !reduceMotion ? .easeOut(duration: 0.22) : nil, value: model.isRestingToday)
        .animation(previewMood == nil && !reduceMotion ? .easeOut(duration: 0.22) : nil, value: displayedFinalMinuteSeconds != nil)
        .animation(previewMood == nil && !reduceMotion ? .easeInOut(duration: 0.20) : nil, value: showHoverTime)
    }

    @ViewBuilder
    private func finalMinuteContent(_ seconds: Int) -> some View {
        let label = Text("\(seconds)")
            .font(.system(size: finalMinuteTextSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(model.centerLabelSwiftUIColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

        if reduceMotion {
            label
        } else {
            label
                .phaseAnimator(EchoPhase.allCases, trigger: seconds) { content, phase in
                    content
                        .scaleEffect(phase == .dissolve ? 1.72 : 0.88)
                        .opacity(phase == .crest ? 0.25 : 0)
                } animation: { phase in
                    phase == .dissolve ? .easeOut(duration: 0.38) : .linear(duration: 0)
                }
                .accessibilityHidden(true)

            label
                .phaseAnimator([false, true], trigger: seconds) { content, enlarged in
                    content.scaleEffect(enlarged ? 1.52 : 1)
                } animation: { enlarged in
                    enlarged ? .easeOut(duration: 0.10) : .spring(response: 0.28, dampingFraction: 0.72)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
        }
    }

    @ViewBuilder
    private var baseCenterLabel: some View {
        if isDisplayingRestDay {
            Text("休息")
                .font(.system(size: labelTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(model.waitingLabelSwiftUIColor)
                .lineLimit(1)
        } else if isDisplayingFinished {
            Text(completedText)
                .font(.system(size: labelTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(model.completedLabelSwiftUIColor)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Text(isDisplayingWaiting ? waitingText : workText)
                .font(.system(size: labelTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(isDisplayingWaiting ? model.waitingLabelSwiftUIColor : model.centerLabelSwiftUIColor)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
        }
    }

    private var hoverStatus: some View {
        Text(model.coreHoverTime)
            .font(.system(size: remainingTextSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.50)
            .foregroundStyle(hoverTextColor)
    }

    private var displayText: String {
        if let seconds = displayedFinalMinuteSeconds { return "\(seconds)秒" }
        if showHoverTime { return model.coreHoverTime }
        if isDisplayingRestDay { return "休息" }
        if isDisplayingFinished { return completedText }
        return isDisplayingWaiting ? waitingText : workText
    }

    private var displayedEarTime: (hours: String, minutes: String)? {
        guard let previewMood else { return model.earTime }
        switch previewMood {
        case .resting:
            return (
                String(format: "%02d", model.startMinutes / 60),
                String(format: "%02d", model.startMinutes % 60)
            )
        case .focused: return ("02", "20")
        case .expectant: return ("00", "04")
        case .relaxed: return nil
        }
    }

    private var displayedFinalMinuteSeconds: Int? {
        previewMood == nil ? model.finalMinuteSeconds : nil
    }

    private var isDisplayingFinished: Bool {
        previewMood == .relaxed || (previewMood == nil && !model.isRestingToday && model.snapshot.phase == .finished)
    }

    private var isDisplayingRestDay: Bool {
        previewMood == nil && model.isRestingToday
    }

    private var isDisplayingWaiting: Bool {
        previewMood == .resting || (previewMood == nil && model.snapshot.phase == .waiting)
    }

    private var showHoverTime: Bool {
        previewMood == nil
            && isHoveringCore
            && !isDisplayingRestDay
            && !isDisplayingFinished
            && displayedFinalMinuteSeconds == nil
    }

    private var waitingText: String { model.waitingLabel.isEmpty ? "待命" : model.waitingLabel }
    private var workText: String { model.centerLabel.isEmpty ? "牛马" : model.centerLabel }
    private var completedText: String { model.completedLabel.isEmpty ? "下班" : model.completedLabel }
    private var labelTextSize: CGFloat {
        let side = CGFloat(model.widgetSize)
        return max(side * CowOptics.values(for: side).labelRatio, 10)
    }
    private var remainingTextSize: CGFloat {
        let side = CGFloat(model.widgetSize)
        return max(side * CowOptics.values(for: side).remainingRatio, 10)
    }
    private var finalMinuteTextSize: CGFloat { max(model.widgetSize * 0.32, 12.8) }

    private var hoverTextColor: Color {
        isDisplayingWaiting ? model.waitingLabelSwiftUIColor : model.centerLabelSwiftUIColor
    }

    /// Rounding small marks to a physical-pixel boundary keeps eyes and
    /// nostrils crisp on both 1x and Retina displays without extra layers.
    private func pixelAligned(_ value: CGFloat) -> CGFloat {
        let scale = max(displayScale, 1)
        return (value * scale).rounded() / scale
    }

}
