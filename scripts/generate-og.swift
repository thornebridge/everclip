#!/usr/bin/env swift
import AppKit

let w = 1200, h = 630
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let gc = ctx.cgContext

// Flip coordinate system so Y=0 is at the top (like screen coords)
gc.translateBy(x: 0, y: CGFloat(h))
gc.scaleBy(x: 1, y: -1)

// Background
gc.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1))
gc.fill(CGRect(x: 0, y: 0, width: w, height: h))

// Subtle green radial glow centered in upper third
let glowCenter = CGPoint(x: CGFloat(w) / 2, y: 240)
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 0, green: 1, blue: 0.529, alpha: 0.12),
        CGColor(red: 0, green: 1, blue: 0.529, alpha: 0),
    ] as CFArray,
    locations: [0, 1]
)!
gc.drawRadialGradient(gradient, startCenter: glowCenter, startRadius: 0,
                       endCenter: glowCenter, endRadius: 320, options: [])

// --- Text rendering needs un-flipped context for NSAttributedString ---
// Save flipped state, temporarily un-flip for text
gc.saveGState()
gc.translateBy(x: 0, y: CGFloat(h))
gc.scaleBy(x: 1, y: -1)
// Now we're back to bottom-left origin for NSAttributedString.draw()

// Icon background (white rounded rect)
let iconSize: CGFloat = 72
let iconX = (CGFloat(w) - iconSize) / 2
let iconY = CGFloat(h) - 190  // 190px from top in bottom-left coords
let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
let iconPath = CGPath(roundedRect: iconRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
gc.addPath(iconPath)
gc.setFillColor(CGColor.white)
gc.fillPath()
gc.addPath(iconPath)
gc.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
gc.setLineWidth(1)
gc.strokePath()

// "e" in icon
let iconFont = NSFont.systemFont(ofSize: 42, weight: .black)
let eAttrs: [NSAttributedString.Key: Any] = [
    .font: iconFont,
    .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
]
let eStr = NSAttributedString(string: "e", attributes: eAttrs)
let eSize = eStr.size()
eStr.draw(at: NSPoint(x: iconX + (iconSize - eSize.width) / 2 - 3, y: iconY + (iconSize - eSize.height) / 2 - 1))

// Green dot
gc.setFillColor(CGColor(red: 0, green: 1, blue: 0.529, alpha: 1))
gc.fillEllipse(in: CGRect(
    x: iconX + iconSize / 2 + 12,
    y: iconY + (iconSize - eSize.height) / 2 + 5,
    width: 9, height: 9
))

// "everclip." wordmark — centered below icon
let wordFont = NSFont.systemFont(ofSize: 56, weight: .heavy)
let wordAttrs: [NSAttributedString.Key: Any] = [
    .font: wordFont,
    .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1),
    .kern: -2.0 as NSNumber
]
let word = NSMutableAttributedString(string: "everclip", attributes: wordAttrs)
let dotAttrs: [NSAttributedString.Key: Any] = [
    .font: wordFont,
    .foregroundColor: NSColor(red: 0, green: 1, blue: 0.529, alpha: 1),
    .kern: -2.0 as NSNumber
]
word.append(NSAttributedString(string: ".", attributes: dotAttrs))
let wordSize = word.size()
let wordY = CGFloat(h) - 290  // below icon
word.draw(at: NSPoint(x: (CGFloat(w) - wordSize.width) / 2, y: wordY))

// Tagline
let tagFont = NSFont.systemFont(ofSize: 24, weight: .medium)
let tagAttrs: [NSAttributedString.Key: Any] = [
    .font: tagFont,
    .foregroundColor: NSColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
]
let tag = NSAttributedString(string: "Never lose a copy again.", attributes: tagAttrs)
let tagSize = tag.size()
let tagY = CGFloat(h) - 345
tag.draw(at: NSPoint(x: (CGFloat(w) - tagSize.width) / 2, y: tagY))

// Subtitle chips
let subFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1),
    .kern: 0.3 as NSNumber
]
let sub = NSAttributedString(string: "NATIVE SWIFT  \u{00B7}  APPLE SILICON  \u{00B7}  FREE & OPEN SOURCE", attributes: subAttrs)
let subSize = sub.size()
let subY = CGFloat(h) - 395
sub.draw(at: NSPoint(x: (CGFloat(w) - subSize.width) / 2, y: subY))

// Footer
let footFont = NSFont.systemFont(ofSize: 11, weight: .medium)
let footAttrs: [NSAttributedString.Key: Any] = [
    .font: footFont,
    .foregroundColor: NSColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1),
    .kern: 0.8 as NSNumber
]
let foot = NSAttributedString(string: "POWERED BY THORNEBRIDGE", attributes: footAttrs)
let footSize = foot.size()
foot.draw(at: NSPoint(x: (CGFloat(w) - footSize.width) / 2, y: 24))

gc.restoreGState()
NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: "docs/assets/og.png"))
print("Generated docs/assets/og.png (\(w)x\(h))")
