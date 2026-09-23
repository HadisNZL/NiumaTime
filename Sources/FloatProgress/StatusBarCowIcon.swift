import AppKit

/// A single lightweight menu-bar mark: the focused cow rendered as a native
/// template image, so macOS supplies the correct light/dark appearance.
enum StatusBarCowIcon {
    /// Reused by the status button so changing digits never changes their
    /// advance width or allocates a new attributed title every second.
    @MainActor static let countdownFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize,
        weight: .regular
    )

    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            drawHorn(isLeft: true)
            drawHorn(isLeft: false)
            drawEar(isLeft: true)
            drawEar(isLeft: false)
            drawHead()

            // Focused expression: two open round eyes, matching the floating cow.
            NSBezierPath(ovalIn: NSRect(x: 6.25, y: 8.45, width: 1.45, height: 1.45)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10.3, y: 8.45, width: 1.45, height: 1.45)).fill()

            drawMuzzle()
            NSBezierPath(ovalIn: NSRect(x: 7.15, y: 4.3, width: 0.85, height: 0.8)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10.0, y: 4.3, width: 0.85, height: 0.8)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "牛马"
        return image
    }()

    private static func drawHead() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 5.25, y: 13.3))
        path.curve(
            to: NSPoint(x: 12.75, y: 13.3),
            controlPoint1: NSPoint(x: 6.35, y: 14.4),
            controlPoint2: NSPoint(x: 11.65, y: 14.4)
        )
        path.curve(
            to: NSPoint(x: 13.25, y: 6.3),
            controlPoint1: NSPoint(x: 13.9, y: 11.7),
            controlPoint2: NSPoint(x: 13.75, y: 7.9)
        )
        path.curve(
            to: NSPoint(x: 9.0, y: 2.1),
            controlPoint1: NSPoint(x: 12.4, y: 3.3),
            controlPoint2: NSPoint(x: 10.65, y: 2.1)
        )
        path.curve(
            to: NSPoint(x: 4.75, y: 6.3),
            controlPoint1: NSPoint(x: 7.35, y: 2.1),
            controlPoint2: NSPoint(x: 5.6, y: 3.3)
        )
        path.curve(
            to: NSPoint(x: 5.25, y: 13.3),
            controlPoint1: NSPoint(x: 4.25, y: 7.9),
            controlPoint2: NSPoint(x: 4.1, y: 11.7)
        )
        path.close()
        stroke(path, width: 1.25)
    }

    private static func drawEar(isLeft: Bool) {
        let path = NSBezierPath()
        let direction: CGFloat = isLeft ? -1 : 1
        let innerX: CGFloat = isLeft ? 5.15 : 12.85
        path.move(to: NSPoint(x: innerX, y: 12.4))
        path.curve(
            to: NSPoint(x: innerX + direction * 4.0, y: 13.0),
            controlPoint1: NSPoint(x: innerX + direction * 1.5, y: 13.7),
            controlPoint2: NSPoint(x: innerX + direction * 3.45, y: 13.8)
        )
        path.curve(
            to: NSPoint(x: innerX, y: 10.55),
            controlPoint1: NSPoint(x: innerX + direction * 3.65, y: 10.7),
            controlPoint2: NSPoint(x: innerX + direction * 1.45, y: 10.35)
        )
        path.close()
        stroke(path, width: 1.15)
    }

    private static func drawHorn(isLeft: Bool) {
        let path = NSBezierPath()
        if isLeft {
            path.move(to: NSPoint(x: 6.0, y: 13.9))
            path.curve(
                to: NSPoint(x: 5.65, y: 16.15),
                controlPoint1: NSPoint(x: 5.2, y: 14.75),
                controlPoint2: NSPoint(x: 5.25, y: 15.7)
            )
            path.curve(
                to: NSPoint(x: 7.25, y: 14.25),
                controlPoint1: NSPoint(x: 6.2, y: 15.6),
                controlPoint2: NSPoint(x: 6.8, y: 14.9)
            )
        } else {
            path.move(to: NSPoint(x: 12.0, y: 13.9))
            path.curve(
                to: NSPoint(x: 12.35, y: 16.15),
                controlPoint1: NSPoint(x: 12.8, y: 14.75),
                controlPoint2: NSPoint(x: 12.75, y: 15.7)
            )
            path.curve(
                to: NSPoint(x: 10.75, y: 14.25),
                controlPoint1: NSPoint(x: 11.8, y: 15.6),
                controlPoint2: NSPoint(x: 11.2, y: 14.9)
            )
        }
        stroke(path, width: 1.15)
    }

    private static func drawMuzzle() {
        let path = NSBezierPath(
            roundedRect: NSRect(x: 6.3, y: 3.55, width: 5.4, height: 2.7),
            xRadius: 1.35,
            yRadius: 1.35
        )
        stroke(path, width: 1.0)
    }

    private static func stroke(_ path: NSBezierPath, width: CGFloat) {
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}
