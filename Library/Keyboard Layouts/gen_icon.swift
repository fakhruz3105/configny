#!/usr/bin/env swift
// Generate the input-source icon for ArabicBuckwalter.keylayout.
// macOS picks up an .icns beside a .keylayout when the base names match.
//
//   swift gen_icon.swift <out.icns>
//
// The icon is drawn in colour rather than as a template: a standalone .icns
// cannot opt into template rendering, so it has to read on light and dark
// menu bars as-is.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let glyph = "ب"  // ba - Arabic, and B for Buckwalter
let fill = CGColor(srgbRed: 0.09, green: 0.49, blue: 0.30, alpha: 1)
let ink = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift gen_icon.swift <out.icns>\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])

func line(_ size: CGFloat) -> CTLine {
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, "ar" as CFString)!
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: attrs))
}

func render(_ px: Int) -> CGImage {
    let s = CGFloat(px)
    let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    let inset = s * 0.03
    let rect = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: inset, dy: inset)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil))
    ctx.setFillColor(fill)
    ctx.fillPath()

    // Size the glyph by its inked bounds (dot included), not its line height,
    // so it fills the square the same way at every pixel size.
    let probe = line(100)
    let pb = CTLineGetImageBounds(probe, ctx)
    let fontSize = 100 * (s * 0.62) / max(pb.width, pb.height)
    let l = line(fontSize)
    let b = CTLineGetImageBounds(l, ctx)
    ctx.textPosition = CGPoint(x: (s - b.width) / 2 - b.minX, y: (s - b.height) / 2 - b.minY)
    CTLineDraw(l, ctx)
    return ctx.makeImage()!
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("icon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset.deletingLastPathComponent()) }

for pt in [16, 32, 128] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        let dest = CGImageDestinationCreateWithURL(
            iconset.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, render(pt * scale), nil)
        guard CGImageDestinationFinalize(dest) else { fatalError("failed to write \(name)") }
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
