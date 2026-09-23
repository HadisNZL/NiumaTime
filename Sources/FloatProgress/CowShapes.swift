import SwiftUI

enum CowLayout {
    static let earCenterOffset: CGFloat = 0.58
    static let earWidth: CGFloat = 0.49
    static let earOverhang: CGFloat = 0.05

    static func panelWidth(for side: CGFloat, showsEars: Bool = true) -> CGFloat {
        guard showsEars else { return side }
        // The ear path bends 5% beyond its frame. Allow for that, its outline,
        // and two points of clear space on either edge at every widget size.
        let earReach = side * (earCenterOffset + earWidth * (0.5 + earOverhang))
        let outlineHalfWidth = max(side * 0.020, 1.1) / 2
        return 2 * (earReach + outlineHalfWidth + 2)
    }

    static func panelSize(for side: CGFloat, showsEars: Bool = true) -> NSSize {
        NSSize(width: panelWidth(for: side, showsEars: showsEars), height: side)
    }
}

/// Optical compensation keeps the cow readable at 40 pt without making the
/// 88 pt version feel swollen. These are three deliberate drawings blended
/// between size ranges, rather than a single icon scaled mechanically.
struct CowOptics {
    let headWidth: CGFloat
    let headHeight: CGFloat
    let headCenterY: CGFloat
    let hornSize: CGFloat
    let hornX: CGFloat
    let outlineRatio: CGFloat
    let eyeX: CGFloat
    let focusedEyeDiameter: CGFloat
    let muzzleWidth: CGFloat
    let muzzleHeight: CGFloat
    let muzzleY: CGFloat
    let nostrilDiameter: CGFloat
    let nostrilX: CGFloat
    let patchWidth: CGFloat
    let patchHeight: CGFloat
    let expressionWidth: CGFloat
    let expressionStrokeRatio: CGFloat
    let earLabelRatio: CGFloat
    let labelRatio: CGFloat
    let remainingRatio: CGFloat

    static func values(for side: CGFloat) -> CowOptics {
        let compact = CowOptics(
            headWidth: 0.82, headHeight: 0.84, headCenterY: 0.52,
            hornSize: 0.195, hornX: 0.225, outlineRatio: 0.023,
            eyeX: 0.125, focusedEyeDiameter: 0.086,
            muzzleWidth: 0.49, muzzleHeight: 0.23, muzzleY: 0.765,
            nostrilDiameter: 0.052, nostrilX: 0.102,
            patchWidth: 0.22, patchHeight: 0.14,
            expressionWidth: 0.140, expressionStrokeRatio: 0.032,
            earLabelRatio: 0.170,
            labelRatio: 0.255, remainingRatio: 0.215
        )
        let regular = CowOptics(
            headWidth: 0.78, headHeight: 0.80, headCenterY: 0.53,
            hornSize: 0.18, hornX: 0.22, outlineRatio: 0.020,
            eyeX: 0.12, focusedEyeDiameter: 0.075,
            muzzleWidth: 0.46, muzzleHeight: 0.22, muzzleY: 0.770,
            nostrilDiameter: 0.043, nostrilX: 0.098,
            patchWidth: 0.20, patchHeight: 0.13,
            expressionWidth: 0.130, expressionStrokeRatio: 0.025,
            earLabelRatio: 0.155,
            labelRatio: 0.24, remainingRatio: 0.205
        )
        let spacious = CowOptics(
            headWidth: 0.75, headHeight: 0.78, headCenterY: 0.535,
            hornSize: 0.17, hornX: 0.215, outlineRatio: 0.017,
            eyeX: 0.115, focusedEyeDiameter: 0.068,
            muzzleWidth: 0.43, muzzleHeight: 0.205, muzzleY: 0.775,
            nostrilDiameter: 0.036, nostrilX: 0.092,
            patchWidth: 0.18, patchHeight: 0.12,
            expressionWidth: 0.120, expressionStrokeRatio: 0.020,
            earLabelRatio: 0.145,
            labelRatio: 0.225, remainingRatio: 0.19
        )

        if side <= 62 {
            return mix(compact, regular, amount: min(max((side - 40) / 22, 0), 1))
        }
        return mix(regular, spacious, amount: min(max((side - 62) / 26, 0), 1))
    }

    private static func mix(_ a: CowOptics, _ b: CowOptics, amount: CGFloat) -> CowOptics {
        func value(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * amount }
        return CowOptics(
            headWidth: value(a.headWidth, b.headWidth),
            headHeight: value(a.headHeight, b.headHeight),
            headCenterY: value(a.headCenterY, b.headCenterY),
            hornSize: value(a.hornSize, b.hornSize),
            hornX: value(a.hornX, b.hornX),
            outlineRatio: value(a.outlineRatio, b.outlineRatio),
            eyeX: value(a.eyeX, b.eyeX),
            focusedEyeDiameter: value(a.focusedEyeDiameter, b.focusedEyeDiameter),
            muzzleWidth: value(a.muzzleWidth, b.muzzleWidth),
            muzzleHeight: value(a.muzzleHeight, b.muzzleHeight),
            muzzleY: value(a.muzzleY, b.muzzleY),
            nostrilDiameter: value(a.nostrilDiameter, b.nostrilDiameter),
            nostrilX: value(a.nostrilX, b.nostrilX),
            patchWidth: value(a.patchWidth, b.patchWidth),
            patchHeight: value(a.patchHeight, b.patchHeight),
            expressionWidth: value(a.expressionWidth, b.expressionWidth),
            expressionStrokeRatio: value(a.expressionStrokeRatio, b.expressionStrokeRatio),
            earLabelRatio: value(a.earLabelRatio, b.earLabelRatio),
            labelRatio: value(a.labelRatio, b.labelRatio),
            remainingRatio: value(a.remainingRatio, b.remainingRatio)
        )
    }
}

/// Broad forehead and tapered cheeks make the whole widget read as a cow head.
struct CowHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.07))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.07))
        path.addCurve(
            to: CGPoint(x: w * 0.91, y: h * 0.25),
            control1: CGPoint(x: w * 0.83, y: h * 0.07),
            control2: CGPoint(x: w * 0.91, y: h * 0.13)
        )
        path.addLine(to: CGPoint(x: w * 0.91, y: h * 0.55))
        path.addCurve(
            to: CGPoint(x: w * 0.77, y: h * 0.89),
            control1: CGPoint(x: w * 0.91, y: h * 0.72),
            control2: CGPoint(x: w * 0.84, y: h * 0.83)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.23, y: h * 0.89),
            control: CGPoint(x: w * 0.50, y: h * 1.01)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.09, y: h * 0.55),
            control1: CGPoint(x: w * 0.16, y: h * 0.83),
            control2: CGPoint(x: w * 0.09, y: h * 0.72)
        )
        path.addLine(to: CGPoint(x: w * 0.09, y: h * 0.25))
        path.addCurve(
            to: CGPoint(x: w * 0.28, y: h * 0.07),
            control1: CGPoint(x: w * 0.09, y: h * 0.13),
            control2: CGPoint(x: w * 0.17, y: h * 0.07)
        )
        path.closeSubpath()
        return path
    }
}

/// An asymmetric forehead marking that stays clear of the eye and text areas.
struct CowForeheadPatchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.76, y: h * 0.06))
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.35),
            control1: CGPoint(x: w * 0.92, y: h * 0.06),
            control2: CGPoint(x: w * 0.99, y: h * 0.20)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.63),
            control: CGPoint(x: w * 0.74, y: h * 0.49)
        )
        path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.94))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.09, y: h * 0.83),
            control: CGPoint(x: w * 0.23, y: h * 0.97)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.24, y: h * 0.30),
            control: CGPoint(x: w * 0.03, y: h * 0.54)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.76, y: h * 0.06),
            control: CGPoint(x: w * 0.43, y: h * 0.12)
        )
        path.closeSubpath()
        return path
    }
}

/// Shallow downward arcs read as relaxed, closed eyes at small widget sizes.
struct CowSleepyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.34))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.34),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.90)
        )
        return path
    }
}

/// A simple arched closed eye for the finished, happy expression.
struct CowHappyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.82))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.82),
            control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.08),
            control2: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.08)
        )
        return path
    }
}

/// A short upward-tilted squint, distinct from the two happy arches.
struct CowWinkEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.30))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.48),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.92)
        )
        return path
    }
}

/// Broad, rounded ears retain the first prototype's horizontal silhouette.
struct CowEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w, y: h * 0.35))
        path.addCurve(
            to: CGPoint(x: w * 0.05, y: h * 0.17),
            control1: CGPoint(x: w * 0.70, y: h * 0.04),
            control2: CGPoint(x: w * 0.20, y: -h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.05, y: h * 0.83),
            control1: CGPoint(x: -w * CowLayout.earOverhang, y: h * 0.28),
            control2: CGPoint(x: -w * CowLayout.earOverhang, y: h * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.65),
            control1: CGPoint(x: w * 0.20, y: h * 1.02),
            control2: CGPoint(x: w * 0.70, y: h * 0.96)
        )
        path.closeSubpath()
        return path
    }
}

/// A small curved horn; the base is hidden behind the forehead.
struct CowHornShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.08, y: h))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.28, y: h * 0.03),
            control: CGPoint(x: -w * 0.08, y: h * 0.43)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.95, y: h),
            control: CGPoint(x: w * 0.52, y: h * 0.65)
        )
        path.closeSubpath()
        return path
    }
}
