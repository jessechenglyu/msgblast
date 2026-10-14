#!/usr/bin/env swift
import AppKit

// Reuse the canonical bubble path and its Icon Composer layer spacing.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = try String(contentsOf: root.appendingPathComponent("output/app-icons/msgblast.icon/Assets/SVG Image 2.svg"), encoding: .utf8)
let pathPattern = try NSRegularExpression(pattern: "<path d=\"([^\"]+)\"")
let match = pathPattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source))!
let pathData = String(source[Range(match.range(at: 1), in: source)!])
let tokensPattern = try NSRegularExpression(pattern: "[MCZ]|-?[0-9]+(?:\\.[0-9]+)?")
let tokens = tokensPattern.matches(in: pathData, range: NSRange(pathData.startIndex..., in: pathData)).map { String(pathData[Range($0.range, in: pathData)!]) }
let bubble = CGMutablePath()
var i = 0
func point() -> CGPoint {
    let value = CGPoint(x: Double(tokens[i])!, y: Double(tokens[i + 1])!)
    i += 2
    return value
}
while i < tokens.count {
    let command = tokens[i]; i += 1
    switch command {
    case "M": bubble.move(to: point())
    case "C": let first = point(), second = point(), end = point(); bubble.addCurve(to: end, control1: first, control2: second)
    case "Z": bubble.closeSubpath()
    default: fatalError("Unsupported canonical path command: \(command)")
    }
}
let side = 144
let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(side))
context.scaleBy(x: 1, y: -1)
let spacing = 160.0 / 4.1
let height = 101 + spacing * 2
let scale = 136 / height
context.translateBy(x: (Double(side) - 176 * scale) / 2, y: 4)
context.scaleBy(x: scale, y: scale)
for layer in 0..<3 {
    context.saveGState()
    context.translateBy(x: 0, y: Double(layer) * spacing)
    // Transparent seams keep all three layers distinct in a monochrome menu bar.
    if layer > 0 {
        context.setBlendMode(.clear)
        context.setLineWidth(16)
        context.addPath(bubble); context.strokePath()
    }
    context.setBlendMode(.normal)
    context.setFillColor(NSColor.black.cgColor)
    context.addPath(bubble); context.fillPath()
    context.restoreGState()
}
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let output = root.appendingPathComponent("msgblast/Resources/QuickAccess/MenuBarIcon.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print(output.path)
