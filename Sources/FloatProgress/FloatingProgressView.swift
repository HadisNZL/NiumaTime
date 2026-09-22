import SwiftUI

struct FloatingProgressView: View {
    private enum EchoPhase: CaseIterable {
        case idle
        case crest
        case dissolve
    }

    @ObservedObject var model: ProgressModel
    let openSettings: () -> Void

    @State private var isHovering = false

    var body: some View {
        GeometryReader { proxy in
            let side = CGFloat(model.circleSize)

            ZStack {
                Circle()
                    .fill(model.backgroundSwiftUIColor.opacity(model.backgroundOpacity))
                    .frame(width: side * 0.62, height: side * 0.62)

                Circle()
                    .trim(from: 0, to: arcLength)
                    .stroke(
                        model.trackSwiftUIColor.opacity(model.trackOpacity),
                        style: StrokeStyle(
                            lineWidth: ringWidth,
                            lineCap: .round,
                            dash: [max(ringWidth * 0.65, 1.4), max(ringWidth * 1.7, 3.6)]
                        )
                    )
                    .rotationEffect(.degrees(arcStartDegrees))
                    .padding(ringInset)

                Circle()
                    .trim(from: 0, to: arcLength * model.snapshot.progress)
                    .stroke(
                        ringColor.opacity(model.progressOpacity),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(arcStartDegrees))
                    .padding(ringInset)

                if model.snapshot.phase == .running,
                   model.snapshot.progress > 0,
                   model.snapshot.progress < 1 {
                    progressBeacon(side: side)
                }

                centerContent
                    .frame(width: side * 0.56, height: side * 0.56)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.20)) { isHovering = hovering }
        }
        .onTapGesture(count: 2, perform: openSettings)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayText)，\(model.statusText)，完成 \(percent) 百分比")
    }

    private func progressBeacon(side: CGFloat) -> some View {
        // The stroke is centered on the inset circle path; use the same radius.
        let radius = side / 2 - ringInset
        let angle = (arcStartDegrees + arcSweepDegrees * model.snapshot.progress) * .pi / 180
        let diameter = model.beaconDiameter

        return Circle()
            .fill(model.beaconSwiftUIColor)
            .frame(width: diameter, height: diameter)
            .position(
                x: side / 2 + cos(angle) * radius,
                y: side / 2 + sin(angle) * radius
            )
    }

    private var centerContent: some View {
        ZStack {
            if let seconds = model.finalMinuteSeconds {
                Text("\(seconds)")
                    .font(.system(size: finalMinuteTextSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.centerLabelSwiftUIColor)
                    .fixedSize(horizontal: true, vertical: false)
                    .phaseAnimator(EchoPhase.allCases, trigger: seconds) { content, phase in
                        content
                            .scaleEffect(phase == .dissolve ? 1.72 : 0.88)
                            .opacity(phase == .crest ? 0.25 : 0)
                    } animation: { phase in
                        phase == .dissolve ? .easeOut(duration: 0.38) : .linear(duration: 0)
                    }
                    .accessibilityHidden(true)

                Text("\(seconds)")
                    .font(.system(size: finalMinuteTextSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.centerLabelSwiftUIColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .phaseAnimator([false, true], trigger: seconds) { content, enlarged in
                        content.scaleEffect(enlarged ? 1.52 : 1)
                    } animation: { enlarged in
                        enlarged ? .easeOut(duration: 0.10) : .spring(response: 0.28, dampingFraction: 0.72)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if model.snapshot.phase == .finished {
                Text(completedText)
                    .font(.system(size: labelTextSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(model.completedLabelSwiftUIColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                HStack(spacing: 0) {
                    Text(workTextParts.0)
                        .offset(x: showRemaining ? -textSpread : 0)
                    Text(workTextParts.1)
                        .offset(x: showRemaining ? textSpread : 0)
                }
                .font(.system(size: labelTextSize, weight: .heavy, design: .rounded))
                .foregroundStyle(model.centerLabelSwiftUIColor)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .opacity(showRemaining ? 0 : 1)

                Text(shortRemaining)
                    .font(.system(size: remainingTextSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.centerLabelSwiftUIColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .opacity(showRemaining ? 1 : 0)
                    .offset(y: showRemaining ? 0 : 3)
                    .scaleEffect(showRemaining ? 1 : 0.94)
            }
        }
        .animation(.easeOut(duration: 0.22), value: model.snapshot.phase)
        .animation(.easeOut(duration: 0.22), value: model.finalMinuteSeconds != nil)
    }

    private var arcLength: CGFloat { 5.0 / 6.0 }
    private var arcStartDegrees: Double { 120 }
    private var arcSweepDegrees: Double { 300 }

    private var displayText: String {
        if let seconds = model.finalMinuteSeconds { return "\(seconds)秒" }
        if model.snapshot.phase == .finished { return completedText }
        if isHovering { return shortRemaining }
        return workText
    }

    private var workText: String { model.centerLabel.isEmpty ? "牛马" : model.centerLabel }
    private var completedText: String { model.completedLabel.isEmpty ? "下班" : model.completedLabel }
    private var showRemaining: Bool {
        isHovering && model.snapshot.phase != .finished && model.finalMinuteSeconds == nil
    }
    private var workTextParts: (String, String) {
        let characters = Array(workText)
        let middle = (characters.count + 1) / 2
        return (String(characters.prefix(middle)), String(characters.dropFirst(middle)))
    }

    private var shortRemaining: String {
        let total = max(Int(model.snapshot.remaining.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return String(format: "%02d:%02d", hours, minutes) }
        return String(format: "%02d:%02d", minutes, total % 60)
    }

    private var percent: Int { Int(model.snapshot.progress * 100) }
    private var ringWidth: CGFloat { max(model.circleSize * 0.052, 2.2) }
    private var ringInset: CGFloat { max(model.circleSize * 0.11, 4) }
    private var labelTextSize: CGFloat { max(model.circleSize * 0.24, 10) }
    private var remainingTextSize: CGFloat { max(model.circleSize * 0.205, 10) }
    private var finalMinuteTextSize: CGFloat { max(model.circleSize * 0.32, 12.8) }
    private var textSpread: CGFloat { min(model.circleSize * 0.075, 5) }

    private var ringColor: Color {
        model.progressSwiftUIColor
    }

}
