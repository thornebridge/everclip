#!/usr/bin/env swift
import AppKit

// Generates AppIcon.iconset from a programmatically drawn icon:
// White rounded square, black bold "e", neon green period.

func renderIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let gc = ctx.cgContext

    // Background: white rounded rect (macOS squircle-ish)
    let radius = s * 0.223
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    gc.addPath(bgPath)
    gc.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    gc.fillPath()

    // Subtle inner shadow / border
    gc.addPath(bgPath)
    gc.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
    gc.setLineWidth(s * 0.004)
    gc.strokePath()

    // "e" character
    let fontSize = s * 0.58
    let font = NSFont.systemFont(ofSize: fontSize, weight: .black)
    let eAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
    ]
    let eStr = NSAttributedString(string: "e", attributes: eAttrs)
    let eSize = eStr.size()
    // Center the "e" slightly left to make room for the dot
    let eX = (s - eSize.width) / 2 - s * 0.06
    let eY = (s - eSize.height) / 2 - s * 0.02
    eStr.draw(at: NSPoint(x: eX, y: eY))

    // Green period dot
    let dotRadius = s * 0.052
    let dotX = eX + eSize.width + s * 0.015
    let dotY = eY + s * 0.07
    gc.setFillColor(CGColor(red: 0, green: 1, blue: 0.529, alpha: 1)) // #00ff87
    gc.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotRadius * 2, height: dotRadius * 2))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Create iconset directory
let iconsetDir = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),     ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),     ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),  ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),  ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),  ("icon_512x512@2x.png", 1024),
]

for (name, size) in variants {
    let data = renderIcon(size: size)
    try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
}

print("Generated \(iconsetDir) with \(variants.count) sizes")
