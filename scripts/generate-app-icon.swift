#!/usr/bin/env swift

import AppKit
import Foundation

private let canvas: CGFloat = 1024
private let fileManager = FileManager.default
private let scriptURL = URL(fileURLWithPath: #filePath)
private let projectURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
private let resourcesURL = projectURL.appendingPathComponent("Resources", isDirectory: true)
private let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("NiumaTime-AppIcon-\(UUID().uuidString).iconset", isDirectory: true)

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        var encoded = value.bigEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}

private extension NSBezierPath {
    func quadCurve(to end: NSPoint, control: NSPoint) {
        let start = currentPoint
        curve(
            to: end,
            controlPoint1: NSPoint(
                x: start.x + (control.x - start.x) * 2 / 3,
                y: start.y + (control.y - start.y) * 2 / 3
            ),
            controlPoint2: NSPoint(
                x: end.x + (control.x - end.x) * 2 / 3,
                y: end.y + (control.y - end.y) * 2 / 3
            )
        )
    }
}

private func color(_ rgb: Int, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: alpha
    )
}

private func fill(_ path: NSBezierPath, _ value: NSColor) {
    value.setFill()
    path.fill()
}

private func stroke(_ path: NSBezierPath, _ value: NSColor, width: CGFloat) {
    value.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

private func hornPath(mirrored: Bool) -> NSBezierPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: mirrored ? canvas - x : x, y: y)
    }

    let path = NSBezierPath()
    path.move(to: p(454, 628))
    path.curve(
        to: p(264, 806),
        controlPoint1: p(350, 636),
        controlPoint2: p(274, 716)
    )
    path.curve(
        to: p(300, 816),
        controlPoint1: p(258, 826),
        controlPoint2: p(280, 840)
    )
    path.curve(
        to: p(360, 758),
        controlPoint1: p(304, 788),
        controlPoint2: p(330, 766)
    )
    path.curve(
        to: p(420, 700),
        controlPoint1: p(388, 738),
        controlPoint2: p(408, 718)
    )
    path.curve(
        to: p(454, 628),
        controlPoint1: p(444, 682),
        controlPoint2: p(458, 650)
    )
    path.close()
    return path
}

private func earPath(mirrored: Bool) -> NSBezierPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: mirrored ? canvas - x : x, y: y)
    }

    let path = NSBezierPath()
    path.move(to: p(366, 594))
    path.curve(
        to: p(238, 574),
        controlPoint1: p(316, 606),
        controlPoint2: p(270, 596)
    )
    path.curve(
        to: p(238, 536),
        controlPoint1: p(220, 566),
        controlPoint2: p(220, 544)
    )
    path.curve(
        to: p(366, 558),
        controlPoint1: p(278, 518),
        controlPoint2: p(324, 532)
    )
    path.curve(
        to: p(366, 594),
        controlPoint1: p(382, 568),
        controlPoint2: p(382, 584)
    )
    path.close()
    return path
}

private func innerEarPath(mirrored: Bool) -> NSBezierPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: mirrored ? canvas - x : x, y: y)
    }

    let path = NSBezierPath()
    path.move(to: p(340, 578))
    path.curve(
        to: p(258, 560),
        controlPoint1: p(308, 584),
        controlPoint2: p(280, 576)
    )
    path.curve(
        to: p(340, 558),
        controlPoint1: p(286, 544),
        controlPoint2: p(314, 548)
    )
    path.close()
    return path
}

private func cowHeadPath() -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 316, y: 614))
    path.curve(
        to: NSPoint(x: 456, y: 690),
        controlPoint1: NSPoint(x: 338, y: 666),
        controlPoint2: NSPoint(x: 398, y: 688)
    )
    path.curve(
        to: NSPoint(x: 486, y: 748),
        controlPoint1: NSPoint(x: 480, y: 706),
        controlPoint2: NSPoint(x: 468, y: 730)
    )
    path.curve(
        to: NSPoint(x: 512, y: 716),
        controlPoint1: NSPoint(x: 486, y: 720),
        controlPoint2: NSPoint(x: 500, y: 708)
    )
    path.curve(
        to: NSPoint(x: 538, y: 748),
        controlPoint1: NSPoint(x: 524, y: 708),
        controlPoint2: NSPoint(x: 538, y: 720)
    )
    path.curve(
        to: NSPoint(x: 568, y: 690),
        controlPoint1: NSPoint(x: 556, y: 730),
        controlPoint2: NSPoint(x: 544, y: 706)
    )
    path.curve(
        to: NSPoint(x: 708, y: 614),
        controlPoint1: NSPoint(x: 626, y: 688),
        controlPoint2: NSPoint(x: 686, y: 666)
    )
    path.curve(
        to: NSPoint(x: 672, y: 340),
        controlPoint1: NSPoint(x: 714, y: 520),
        controlPoint2: NSPoint(x: 704, y: 406)
    )
    path.curve(
        to: NSPoint(x: 352, y: 340),
        controlPoint1: NSPoint(x: 622, y: 292),
        controlPoint2: NSPoint(x: 402, y: 292)
    )
    path.curve(
        to: NSPoint(x: 316, y: 614),
        controlPoint1: NSPoint(x: 320, y: 406),
        controlPoint2: NSPoint(x: 310, y: 520)
    )
    path.close()
    return path
}

private func muzzlePath() -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 338, y: 458))
    path.curve(
        to: NSPoint(x: 686, y: 458),
        controlPoint1: NSPoint(x: 420, y: 480),
        controlPoint2: NSPoint(x: 604, y: 480)
    )
    path.curve(
        to: NSPoint(x: 760, y: 354),
        controlPoint1: NSPoint(x: 730, y: 450),
        controlPoint2: NSPoint(x: 756, y: 410)
    )
    path.curve(
        to: NSPoint(x: 650, y: 188),
        controlPoint1: NSPoint(x: 766, y: 264),
        controlPoint2: NSPoint(x: 720, y: 210)
    )
    path.curve(
        to: NSPoint(x: 374, y: 188),
        controlPoint1: NSPoint(x: 580, y: 164),
        controlPoint2: NSPoint(x: 444, y: 164)
    )
    path.curve(
        to: NSPoint(x: 264, y: 354),
        controlPoint1: NSPoint(x: 304, y: 210),
        controlPoint2: NSPoint(x: 258, y: 264)
    )
    path.curve(
        to: NSPoint(x: 338, y: 458),
        controlPoint1: NSPoint(x: 268, y: 410),
        controlPoint2: NSPoint(x: 294, y: 450)
    )
    path.close()
    return path
}

private func drawIcon(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.saveGState()
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.cgContext.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    context.shouldAntialias = true
    context.imageInterpolation = .high

    let pixel = canvas / CGFloat(size)

    let plateRect = NSRect(x: 76, y: 66, width: 872, height: 872)
    let plate = NSBezierPath(roundedRect: plateRect, xRadius: 208, yRadius: 208)
    context.cgContext.saveGState()
    if size >= 64 {
        let shadow = NSShadow()
        shadow.shadowColor = color(0x241E53, alpha: 0.22)
        shadow.shadowBlurRadius = 34
        shadow.shadowOffset = NSSize(width: 0, height: -22)
        shadow.set()
    }
    NSGradient(starting: color(0x706BE8), ending: color(0x4B43B8))?
        .draw(in: plate, angle: -90)
    context.cgContext.restoreGState()

    // Scale the complete mascot as one unit so all facial proportions stay
    // unchanged while it occupies the purple plate more confidently.
    context.cgContext.saveGState()
    context.cgContext.translateBy(x: 512, y: 500)
    context.cgContext.scaleBy(x: 1.08, y: 1.08)
    context.cgContext.translateBy(x: -512, y: -500)

    // High-contrast silhouette based on the supplied reference: the horns,
    // ears and face remain readable even at the 16-point Finder size.
    fill(hornPath(mirrored: false), color(0xFFFDF7))
    fill(hornPath(mirrored: true), color(0xFFFDF7))
    fill(earPath(mirrored: false), color(0xFFFDF7))
    fill(earPath(mirrored: true), color(0xFFFDF7))
    fill(innerEarPath(mirrored: false), color(0xC9C5FF))
    fill(innerEarPath(mirrored: true), color(0xC9C5FF))
    fill(cowHeadPath(), color(0xFFFDFB))

    let featureColor = color(0x3D368F)
    let leftEye = NSBezierPath()
    leftEye.move(to: NSPoint(x: 362, y: 548))
    leftEye.curve(
        to: NSPoint(x: 448, y: 548),
        controlPoint1: NSPoint(x: 382, y: 582),
        controlPoint2: NSPoint(x: 428, y: 582)
    )
    stroke(leftEye, featureColor, width: max(18, pixel * 1.05))

    let rightEye = NSBezierPath()
    rightEye.move(to: NSPoint(x: 576, y: 548))
    rightEye.curve(
        to: NSPoint(x: 662, y: 548),
        controlPoint1: NSPoint(x: 596, y: 582),
        controlPoint2: NSPoint(x: 642, y: 582)
    )
    stroke(rightEye, featureColor, width: max(18, pixel * 1.05))

    let muzzle = muzzlePath()
    fill(muzzle, color(0xF1EFFF))
    stroke(muzzle, featureColor, width: max(13, pixel * 0.95))

    // Keep the nostrils as tiny corner accents so the calendar date can use
    // nearly the full muzzle rather than competing with facial decoration.
    for mirrored in [false, true] {
        let x1: CGFloat = mirrored ? 706 : 318
        let x2: CGFloat = mirrored ? 676 : 348
        let nostril = NSBezierPath()
        nostril.move(to: NSPoint(x: x1, y: 390))
        nostril.curve(
            to: NSPoint(x: x2, y: 410),
            controlPoint1: NSPoint(x: mirrored ? 704 : 320, y: 420),
            controlPoint2: NSPoint(x: mirrored ? 686 : 338, y: 426)
        )
        stroke(nostril, featureColor, width: max(12, pixel * 0.9))
    }

    let centerStyle = NSMutableParagraphStyle()
    centerStyle.alignment = .center
    let dateLabel = NSAttributedString(
        string: "8",
        attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 284, weight: .black),
            .foregroundColor: featureColor,
            .paragraphStyle: centerStyle
        ]
    )
    dateLabel.draw(in: NSRect(x: 318, y: 168, width: 388, height: 302))

    context.cgContext.restoreGState()
    context.cgContext.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url, options: .atomic)
}

private let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for (name, size) in variants {
    try drawIcon(size: size, to: iconsetURL.appendingPathComponent(name))
}
try drawIcon(size: 1024, to: resourcesURL.appendingPathComponent("AppIcon-1024.png"))
try drawIcon(size: 16, to: resourcesURL.appendingPathComponent("AppIcon-16.png"))

// AppKit can read PNG-backed modern ICNS chunks directly. Omitting legacy
// bitmap chunks keeps the bundle small and avoids unnecessary duplicate data.
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
let iconChunks: [(String, String)] = [
    ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]
var body = Data()
for (type, filename) in iconChunks {
    let png = try Data(contentsOf: iconsetURL.appendingPathComponent(filename))
    body.append(Data(type.utf8))
    body.appendBigEndian(UInt32(png.count + 8))
    body.append(png)
}
var icns = Data("icns".utf8)
icns.appendBigEndian(UInt32(body.count + 8))
icns.append(body)
try icns.write(to: icnsURL, options: .atomic)
try? fileManager.removeItem(at: iconsetURL)

print(icnsURL.path)
print(resourcesURL.appendingPathComponent("AppIcon-1024.png").path)
print(resourcesURL.appendingPathComponent("AppIcon-16.png").path)
