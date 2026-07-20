#!/usr/bin/env swift
import AppKit

struct Palette {
    let top: NSColor
    let bottom: NSColor
    let symbol: String
    let title: String
}

func render(size: CGSize, palette: Palette, destination: String, icon: Bool) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    NSGradient(starting: palette.top, ending: palette.bottom)!.draw(in: rect, angle: -45)

    let symbolFont = NSFont.systemFont(ofSize: icon ? size.width * 0.48 : size.height * 0.4)
    let symbolStyle: [NSAttributedString.Key: Any] = [.font: symbolFont]
    let symbol = NSAttributedString(string: palette.symbol, attributes: symbolStyle)
    let symbolSize = symbol.size()
    symbol.draw(at: NSPoint(x: (size.width - symbolSize.width) / 2, y: icon ? (size.height - symbolSize.height) / 2 : size.height * 0.38))

    if !icon {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let title = NSAttributedString(string: palette.title, attributes: [
            .font: NSFont.systemFont(ofSize: 54, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ])
        title.draw(in: NSRect(x: 20, y: 40, width: size.width - 40, height: 80))
    }
    image.unlockFocus()
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 3,
        hasAlpha: false,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: URL(fileURLWithPath: destination), options: .atomic)
}

let shark = Palette(top: NSColor(calibratedRed: 0.02, green: 0.12, blue: 0.26, alpha: 1), bottom: NSColor(calibratedRed: 0, green: 0.65, blue: 0.65, alpha: 1), symbol: "🦈", title: "Henry’s Shark Explorer")
let cat = Palette(top: NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.58, alpha: 1), bottom: NSColor(calibratedRed: 0.62, green: 0.32, blue: 0.9, alpha: 1), symbol: "🐈", title: "Kate’s Cat Math Adventure")

try render(size: CGSize(width: 1024, height: 1024), palette: shark, destination: "apps/shark-explorer/Resources/Assets.xcassets/AppIcon.appiconset/shark-icon.png", icon: true)
try render(size: CGSize(width: 900, height: 600), palette: shark, destination: "apps/shark-explorer/Resources/Assets.xcassets/SharkSplash.imageset/shark-splash.png", icon: false)
try render(size: CGSize(width: 1024, height: 1024), palette: cat, destination: "apps/cat-math/Resources/Assets.xcassets/CatAppIcon.appiconset/cat-icon.png", icon: true)
try render(size: CGSize(width: 900, height: 600), palette: cat, destination: "apps/cat-math/Resources/Assets.xcassets/CatSplash.imageset/cat-splash.png", icon: false)
