import AppKit

enum StatusBarCalendarIcon {
    @MainActor static let countdownFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize,
        weight: .regular
    )

    static func image(for date: Date, calendar: Calendar = .current) -> NSImage {
        let day = calendar.component(.day, from: date)
        let image = NSImage(size: NSSize(width: 19, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // A solid binding bar and an open paper outline stay legible in the
            // compact menu bar while looking lighter than a boxed number.
            let binding = NSBezierPath(roundedRect: NSRect(x: 1, y: 13.7, width: 17, height: 3.3), xRadius: 1.65, yRadius: 1.65)
            binding.fill()

            let paper = NSBezierPath()
            paper.move(to: NSPoint(x: 1.6, y: 14.2))
            paper.line(to: NSPoint(x: 1.6, y: 3.2))
            paper.curve(
                to: NSPoint(x: 4, y: 1),
                controlPoint1: NSPoint(x: 1.6, y: 1.75),
                controlPoint2: NSPoint(x: 2.6, y: 1)
            )
            paper.line(to: NSPoint(x: 15, y: 1))
            paper.curve(
                to: NSPoint(x: 17.4, y: 3.2),
                controlPoint1: NSPoint(x: 16.4, y: 1),
                controlPoint2: NSPoint(x: 17.4, y: 1.75)
            )
            paper.line(to: NSPoint(x: 17.4, y: 14.2))
            paper.lineWidth = 1.35
            paper.lineCapStyle = .round
            paper.lineJoinStyle = .round
            paper.stroke()

            let value = String(day) as NSString
            let font = NSFont.monospacedDigitSystemFont(ofSize: day < 10 ? 12.2 : 10.6, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let size = value.size(withAttributes: attributes)
            value.draw(
                at: NSPoint(x: (19 - size.width) / 2, y: 1.65),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "日历，" + String(day) + "日"
        return image
    }
}
