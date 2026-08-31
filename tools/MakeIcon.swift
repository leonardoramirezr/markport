import AppKit
import Foundation

// Generates the Markport icon: minimal mark (text lines + arrow).
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }
    let s = size
    ctx.setShouldAntialias(true)

    // Rounded background, near-black.
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bg = CGPath(roundedRect: rect, cornerWidth: s * 0.222, cornerHeight: s * 0.222, transform: nil)
    ctx.addPath(bg)
    ctx.setFillColor(NSColor(calibratedWhite: 0.07, alpha: 1).cgColor)
    ctx.fillPath()

    // Three lines of text.
    let white = NSColor.white.cgColor
    ctx.setFillColor(white)
    let barHeight = s * 0.052
    let widths: [CGFloat] = [0.42, 0.32, 0.24]
    var y = s * 0.66
    for w in widths {
        let bar = CGRect(x: s * 0.28, y: y, width: s * w, height: barHeight)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        ctx.fillPath()
        y -= barHeight * 2.05
    }

    // Export arrow.
    let cx = s * 0.5
    let stemWidth = s * 0.062
    let stemTop = s * 0.44
    let stemBottom = s * 0.28
    let stem = CGRect(x: cx - stemWidth / 2, y: stemBottom, width: stemWidth, height: stemTop - stemBottom)
    ctx.addPath(CGPath(roundedRect: stem, cornerWidth: stemWidth / 2, cornerHeight: stemWidth / 2, transform: nil))
    ctx.fillPath()

    let head = CGMutablePath()
    head.move(to: CGPoint(x: cx - s * 0.115, y: s * 0.30))
    head.addLine(to: CGPoint(x: cx + s * 0.115, y: s * 0.30))
    head.addLine(to: CGPoint(x: cx, y: s * 0.155))
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()

    image.unlockFocus()
    return image
}

let iconset = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (base, scale) in variants {
    let pixels = base * scale
    let image = drawIcon(size: CGFloat(pixels))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    try? png.write(to: iconset.appendingPathComponent(name))
}
print("iconset ready at \(iconset.path)")
