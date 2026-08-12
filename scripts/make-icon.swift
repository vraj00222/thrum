// Renders Thrum's app icon: three bars — dit, dah, dit — on paper-tape cream, with
// the dah in signal blue. The mark is the product's own tape, cropped.
//
// Run: swift scripts/make-icon.swift   (writes mac/Sources/ThrumApp/Resources/Thrum.icns)
import AppKit
import CoreGraphics
import Foundation

let tape = CGColor(red: 0xF7 / 255, green: 0xF6 / 255, blue: 0xE9 / 255, alpha: 1)
let ink = CGColor(red: 0x16 / 255, green: 0x15 / 255, blue: 0x0F / 255, alpha: 1)
let signal = CGColor(red: 0x1F / 255, green: 0x3B / 255, blue: 0xE0 / 255, alpha: 1)
let rule = CGColor(red: 0xE2 / 255, green: 0xE1 / 255, blue: 0xD0 / 255, alpha: 1)

func drawIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // macOS icons sit inset inside their canvas with a squircle-ish rounded rect.
    let inset = s * 0.094
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = rect.width * 0.2237

    let body = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // A soft drop shadow, the way every other dock icon has one.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    ctx.addPath(body)
    ctx.setFillColor(tape)
    ctx.fillPath()
    ctx.restoreGState()

    // Hairline, so the cream body still has an edge on a white background.
    ctx.addPath(body)
    ctx.setStrokeColor(rule)
    ctx.setLineWidth(max(1, s * 0.006))
    ctx.strokePath()

    // A snippet of the tape itself, laid out left to right: dit dah dit, at the true
    // 1 : 3 : 1 ratio with one-unit gaps. Stacked vertically this reads as a division
    // sign; in a row it reads as code.
    let widths: [CGFloat] = [1, 3, 1]
    let colors = [ink, signal, ink]
    let unitCount = widths.reduce(0, +) + CGFloat(widths.count - 1)  // bars plus gaps
    let unit = rect.width * 0.86 / unitCount
    // Thickness equals one unit, so a dit is square and the 1:3 ratio stays true.
    let barHeight = unit
    let barRadius = barHeight * 0.4

    var x = rect.midX - (unitCount * unit) / 2
    for (index, width) in widths.enumerated() {
        let bar = CGRect(x: x, y: rect.midY - barHeight / 2, width: width * unit, height: barHeight)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barRadius,
                           cornerHeight: barRadius, transform: nil))
        ctx.setFillColor(colors[index])
        ctx.fillPath()
        x += width * unit + unit
    }

    return ctx.makeImage()!
}

let root = URL(fileURLWithPath: CommandLine.arguments.first.map {
    URL(fileURLWithPath: $0).deletingLastPathComponent().deletingLastPathComponent().path
} ?? ".")
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Thrum.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The sizes iconutil expects, each at 1x and 2x.
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let image = drawIcon(size: pixels)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = NSSize(width: base, height: base)
        try rep.representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}

// A standalone 1024 for the web favicon and the landing page.
let webPNG = NSBitmapImageRep(cgImage: drawIcon(size: 1024))
try webPNG.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "web/public/icon.png"))

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", "mac/Sources/ThrumApp/Resources/Thrum.icns"]
try process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "Wrote Thrum.icns and web/public/icon.png" : "iconutil failed")

// DMG background: the tape, faint, behind the drag-to-Applications arrow.
let bgW = 1200, bgH = 800
let bgCtx = CGContext(data: nil, width: bgW, height: bgH, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
bgCtx.setFillColor(tape)
bgCtx.fill(CGRect(x: 0, y: 0, width: bgW, height: bgH))
// A strip of morse across the bottom third, well clear of the two icons.
var bx: CGFloat = 90
let bu: CGFloat = 26
for (i, w) in [1, 3, 1, 1, 3, 1, 3, 3, 3, 1, 1, 1].enumerated() {
    let bar = CGRect(x: bx, y: 150, width: CGFloat(w) * bu, height: bu)
    bgCtx.addPath(CGPath(roundedRect: bar, cornerWidth: bu / 2, cornerHeight: bu / 2, transform: nil))
    bgCtx.setFillColor(i == 4 ? signal.copy(alpha: 0.18)! : ink.copy(alpha: 0.10)!)
    bgCtx.fillPath()
    bx += CGFloat(w) * bu + bu
}
try FileManager.default.createDirectory(atPath: "dist", withIntermediateDirectories: true)
let bgRep = NSBitmapImageRep(cgImage: bgCtx.makeImage()!)
bgRep.size = NSSize(width: bgW / 2, height: bgH / 2)   // @2x
try bgRep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "dist/dmg-background.png"))
print("Wrote dist/dmg-background.png")
