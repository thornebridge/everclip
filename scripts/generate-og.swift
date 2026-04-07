#!/usr/bin/env swift
import AppKit

// Generates a 1200x630 PNG OG image with EverClip branding.

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

let s = CGFloat(1) // scale factor

// Background
gc.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1))
gc.fill(CGRect(x: 0, y: 0, width: w, height: h))

// Subtle green radial glow
let glowCenter = CGPoint(x: CGFloat(w) / 2, y: CGFloat(h) * 0.55)
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 0, green: 1, blue: 0.529, alpha: 0.1),
        CGColor(red: 0, green: 1, blue: 0.529, alpha: 0),
    ] as CFArray,
    locations: [0, 1]
)!
gc.drawRadialGradient(gradient, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: 300, options: [])

// Icon (white rounded rect with "e." at top)
let iconSize: CGFloat = 80
let iconX = (CGFloat(w) - iconSize) / 2
let iconY = CGFloat(h) - 520 // from bottom (flipped coords)
let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
let iconPath = CGPath(roundedRect: iconRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
gc.addPath(iconPath)
gc.setFillColor(CGColor.white)
gc.fillPath()
gc.addPath(iconPath)
gc.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
gc.setLineWidth(1)
gc.strokePath()

// "e" in the icon
let iconFont = NSFont.systemFont(ofSize: 48, weight: .black)
let eAttrs: [NSAttributedString.Key: Any] = [.font: iconFont, .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)]
let eStr = NSAttributedString(string: "e", attributes: eAttrs)
let eSize = eStr.size()
eStr.draw(at: NSPoint(x: iconX + (iconSize - eSize.width) / 2 - 4, y: iconY + (iconSize - eSize.height) / 2 - 2))

// Green dot in icon
gc.setFillColor(CGColor(red: 0, green: 1, blue: 0.529, alpha: 1))
gc.fillEllipse(in: CGRect(x: iconX + iconSize / 2 + 14, y: iconY + (iconSize - eSize.height) / 2 + 4, width: 10, height: 10))

// "everclip." wordmark
let wordFont = NSFont.systemFont(ofSize: 52, weight: .heavy)
let wordAttrs: [NSAttributedString.Key: Any] = [.font: wordFont, .foregroundColor: NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1), .kern: -1.5]
let word = NSMutableAttributedString(string: "everclip", attributes: wordAttrs)
let dotAttrs: [NSAttributedString.Key: Any] = [.font: wordFont, .foregroundColor: NSColor(red: 0, green: 1, blue: 0.529, alpha: 1), .kern: -1.5]
word.append(NSAttributedString(string: ".", attributes: dotAttrs))
let wordSize = word.size()
word.draw(at: NSPoint(x: (CGFloat(w) - wordSize.width) / 2, y: CGFloat(h) - 410))

// Tagline
let tagFont = NSFont.systemFont(ofSize: 22, weight: .medium)
let tagAttrs: [NSAttributedString.Key: Any] = [.font: tagFont, .foregroundColor: NSColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1)]
let tag = NSAttributedString(string: "Never lose a copy again.", attributes: tagAttrs)
let tagSize = tag.size()
tag.draw(at: NSPoint(x: (CGFloat(w) - tagSize.width) / 2, y: CGFloat(h) - 360))

// Subtitle
let subFont = NSFont.systemFont(ofSize: 15, weight: .medium)
let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)]
let sub = NSAttributedString(string: "Native Swift  \u{00B7}  Apple Silicon  \u{00B7}  Free & Open Source", attributes: subAttrs)
let subSize = sub.size()
sub.draw(at: NSPoint(x: (CGFloat(w) - subSize.width) / 2, y: CGFloat(h) - 320))

// "Powered by Thornebridge" footer
let footFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
let footAttrs: [NSAttributedString.Key: Any] = [.font: footFont, .foregroundColor: NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1), .kern: 0.5]
let foot = NSAttributedString(string: "POWERED BY THORNEBRIDGE", attributes: footAttrs)
let footSize = foot.size()
foot.draw(at: NSPoint(x: (CGFloat(w) - footSize.width) / 2, y: 30))

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [.compressionFactor: 0.9])!
try! data.write(to: URL(fileURLWithPath: "docs/assets/og.png"))
print("Generated docs/assets/og.png (1200x630)")
