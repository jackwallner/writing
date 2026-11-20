import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the app icon: a cream pen nib on ink blue. Run from the repo root:
//   swift scripts/draw-icon.swift
let size = 1024
let s = CGFloat(size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: s)
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, 1])!
}
let ink = color(0x253C59)
let gradient = CGGradient(colorsSpace: space, colors: [color(0x30496A), color(0x1E3049)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: s), options: [])

// The nib, tip down, a little to the right of center so it reads as held.
ctx.saveGState()
ctx.translateBy(x: 512, y: 512)
ctx.rotate(by: .pi / 9)
ctx.translateBy(x: -512, y: -512)
let nib = CGMutablePath()
nib.move(to: CGPoint(x: 512, y: 850))
nib.addCurve(to: CGPoint(x: 330, y: 470), control1: CGPoint(x: 440, y: 740), control2: CGPoint(x: 330, y: 580))
nib.addLine(to: CGPoint(x: 372, y: 236))
nib.addQuadCurve(to: CGPoint(x: 652, y: 236), control: CGPoint(x: 512, y: 196))
nib.addLine(to: CGPoint(x: 694, y: 470))
nib.addCurve(to: CGPoint(x: 512, y: 850), control1: CGPoint(x: 694, y: 580), control2: CGPoint(x: 584, y: 740))
nib.closeSubpath()
ctx.addPath(nib)
ctx.setFillColor(color(0xF4EDE0))
ctx.fillPath()
// The band where the nib meets the pen.
ctx.setFillColor(color(0xD9CDB8))
let band = CGMutablePath()
band.move(to: CGPoint(x: 362, y: 292))
band.addLine(to: CGPoint(x: 662, y: 292))
band.addLine(to: CGPoint(x: 668, y: 326))
band.addLine(to: CGPoint(x: 356, y: 326))
band.closeSubpath()
ctx.addPath(band)
ctx.fillPath()
// Slit and breather hole.
ctx.setStrokeColor(ink)
ctx.setLineWidth(16)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 512, y: 548))
ctx.addLine(to: CGPoint(x: 512, y: 846))
ctx.strokePath()
ctx.setFillColor(ink)
ctx.fillEllipse(in: CGRect(x: 512 - 34, y: 500 - 34, width: 68, height: 68))
ctx.restoreGState()

let icon = ctx.makeImage()!

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest), "could not write \(path)")
}

func scaled(_ image: CGImage, to side: Int) -> CGImage {
    let small = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    small.interpolationQuality = .high
    small.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    return small.makeImage()!
}

write(icon, to: "Inkling/Assets.xcassets/AppIcon.appiconset/icon.png")
write(scaled(icon, to: 256), to: "docs/icon_256.png")
