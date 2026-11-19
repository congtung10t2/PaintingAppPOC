import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ImageProcessor {
    private let ciContext = CIContext()

    func cgImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #elseif canImport(AppKit)
        return NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }

    func makeBlackAndWhiteCGImage(from data: Data) -> CGImage? {
        guard let ciImage = CIImage(data: data) else { return nil }
        return makeBlackAndWhiteCGImage(from: ciImage)
    }

    func makeBlackAndWhiteCGImage(from cgImage: CGImage) -> CGImage? {
        makeBlackAndWhiteCGImage(from: CIImage(cgImage: cgImage))
    }

    private func makeBlackAndWhiteCGImage(from ciImage: CIImage) -> CGImage? {
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.saturation = 0
        filter.brightness = 0
        filter.contrast = 1.05
        guard let output = filter.outputImage else { return nil }
        return ciContext.createCGImage(output, from: output.extent)
    }

    /// Samples the image and returns `true` when it is essentially monochrome
    /// (only black, white and shades of gray). Pixels are tested on their RGB
    /// channels; a pixel counts as colored when its channels differ by more than
    /// `tolerance` (so small amounts of JPEG noise are ignored). Transparent
    /// pixels are skipped so a white background can not mask a small subject.
    func isBlackAndWhite(_ cgImage: CGImage, tolerance: Int = 16, sampleStep: Int = 4) -> Bool {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        guard width > 0, height > 0 else { return true }

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var coloredPixelCount = 0
        var visitedPixelCount = 0
        for y in stride(from: 0, to: height, by: max(1, sampleStep)) {
            for x in stride(from: 0, to: width, by: max(1, sampleStep)) {
                let i = (y * width + x) * bytesPerPixel
                // Skip fully transparent pixels.
                if pixels[i + 3] < 8 { continue }
                visitedPixelCount += 1
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                // A pixel is colored when its channels are not all close together.
                let maxDiff = max(abs(r - g), abs(g - b), abs(r - b))
                if maxDiff > tolerance {
                    coloredPixelCount += 1
                }
            }
        }

        guard visitedPixelCount > 0 else { return true }
        // Treat the image as black-and-white unless a meaningful share of the
        // visible pixels is colored.
        return CGFloat(coloredPixelCount) / CGFloat(visitedPixelCount) < 0.02
    }

    func imageFromData(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }

    func rgba(from color: Color) -> (UInt8, UInt8, UInt8, UInt8) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255), UInt8(a * 255))
        #elseif canImport(AppKit)
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        return (UInt8(ns.redComponent * 255), UInt8(ns.greenComponent * 255), UInt8(ns.blueComponent * 255), UInt8(ns.alphaComponent * 255))
        #else
        return (255, 0, 0, 255)
        #endif
    }

    func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        return CGRect(origin: origin, size: size)
    }

    func convertToBitmap(_ cgImage: CGImage) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return context.makeImage()
    }

    func applyStroke(points: [CGPoint], lineWidth: CGFloat, color: (UInt8, UInt8, UInt8, UInt8), to cgImage: CGImage) -> CGImage? {
        guard !points.isEmpty else { return cgImage }
        let width = cgImage.width
        let height = cgImage.height
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        drawStroke(points: points, lineWidth: lineWidth, color: color, isEraser: false, in: context)
        return context.makeImage()
    }

    func renderStrokesLayer(size: CGSize, strokes: [Stroke]) -> CGImage? {
        renderStrokesLayer(size: size, strokes: strokes, baseLayer: nil)
    }

    func renderStrokesLayer(size: CGSize, strokes: [Stroke], baseLayer: CGImage?) -> CGImage? {
        guard !strokes.isEmpty || baseLayer != nil else { return nil }
        let scale: CGFloat = 2.0
        let width = max(Int(size.width * scale), 1)
        let height = max(Int(size.height * scale), 1)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // Clear and composite the previously baked layer in its natural
        // (correct) orientation under an identity CTM. A baked CGImage is
        // already upright, so drawing it inside the flipped context below would
        // flip it a second time and cause previously drawn strokes to flip on
        // every new touch.
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        if let baseLayer {
            context.draw(baseLayer, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Match SwiftUI's top-left coordinate system for newly drawn strokes.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)

        for stroke in strokes {
            drawStroke(points: stroke.points, lineWidth: stroke.lineWidth, color: rgba(from: stroke.color), isEraser: stroke.isEraser, in: context)
        }
        return context.makeImage()
    }

    private func drawStroke(points: [CGPoint], lineWidth: CGFloat, color: (UInt8, UInt8, UInt8, UInt8), isEraser: Bool, in context: CGContext) {
        guard !points.isEmpty else { return }
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(lineWidth)

        let cgColor = CGColor(
            red: CGFloat(color.0) / 255.0,
            green: CGFloat(color.1) / 255.0,
            blue: CGFloat(color.2) / 255.0,
            alpha: CGFloat(color.3) / 255.0
        )

        if isEraser {
            context.setBlendMode(.clear)
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        } else {
            context.setBlendMode(.normal)
            context.setStrokeColor(cgColor)
            context.setFillColor(cgColor)
        }

        if points.count == 1 {
            let p = points[0]
            let r = lineWidth / 2
            context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: lineWidth, height: lineWidth))
        } else {
            context.beginPath()
            context.move(to: points[0])
            for p in points.dropFirst() {
                context.addLine(to: p)
            }
            context.strokePath()
        }
        context.restoreGState()
    }

    func floodFill(cgImage: CGImage, start: CGPoint, fillColor: (UInt8, UInt8, UInt8, UInt8), tolerance: Int) -> CGImage? {
        floodFill(cgImage: cgImage, start: start, fillColor: fillColor, tolerance: tolerance, radius: nil)
    }

    func floodFill(cgImage: CGImage, start: CGPoint, fillColor: (UInt8, UInt8, UInt8, UInt8), tolerance: Int, radius: Int?) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let startX = Int(start.x)
        let startY = Int(start.y)
        func index(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }
        func luminance(at i: Int) -> Int {
            // Perceptual luminance approximation.
            (Int(pixels[i]) * 299 + Int(pixels[i + 1]) * 587 + Int(pixels[i + 2]) * 114) / 1000
        }
        func isBarrier(at i: Int) -> Bool {
            // Treat dark lines/outlines as barriers to prevent leaking into unrelated areas.
            luminance(at: i) <= 110
        }
        func withinRadius(_ x: Int, _ y: Int) -> Bool {
            guard let radius else { return true }
            let dx = x - startX
            let dy = y - startY
            return dx * dx + dy * dy <= radius * radius
        }

        let i0 = index(startX, startY)
        let target = (pixels[i0], pixels[i0 + 1], pixels[i0 + 2], pixels[i0 + 3])

        func matches(_ i: Int) -> Bool {
            if isBarrier(at: i) { return false }
            let dr = Int(pixels[i]) - Int(target.0)
            let dg = Int(pixels[i + 1]) - Int(target.1)
            let db = Int(pixels[i + 2]) - Int(target.2)
            return abs(dr) <= tolerance && abs(dg) <= tolerance && abs(db) <= tolerance
        }

        func isSameAsFill(_ i: Int) -> Bool {
            pixels[i] == fillColor.0 && pixels[i + 1] == fillColor.1 && pixels[i + 2] == fillColor.2 && pixels[i + 3] == fillColor.3
        }

        if isBarrier(at: i0) || isSameAsFill(i0) { return nil }

        var stack = [(startX, startY)]
        var visited = [Bool](repeating: false, count: width * height)

        while let (x, y) = stack.popLast() {
            if x < 0 || y < 0 || x >= width || y >= height { continue }
            if !withinRadius(x, y) { continue }
            let vi = y * width + x
            if visited[vi] { continue }
            visited[vi] = true
            let i = index(x, y)
            if !matches(i) { continue }
            pixels[i] = fillColor.0
            pixels[i + 1] = fillColor.1
            pixels[i + 2] = fillColor.2
            pixels[i + 3] = fillColor.3
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        }

        return context.makeImage()
    }
}
