import CoreGraphics
import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum GalleryCatalog {
    static func makeImage(for picture: GalleryPicture, size: CGSize) -> CGImage? {
        switch picture.content {
        case .drawing(let draw):
            return renderDrawing(draw, size: size)
        case .image(let cgImage):
            return cgImage
        }
    }

    static let allPictures: [GalleryPicture] = drawnPictures + customRealPictures
    static let drawings: [GalleryPicture] = drawnPictures
    static let customRealPictures: [GalleryPicture] = loadCustomRealPictures()

    private static func loadCustomRealPictures() -> [GalleryPicture] {
        var results: [GalleryPicture] = []

        if let sheet = loadCGImage(named: "10pics") {
            let columns = 5
            let rows = 2
            let tileWidth = sheet.width / columns
            let tileHeight = sheet.height / rows

            var index = 1
            for row in 0..<rows {
                for col in 0..<columns {
                    let rect = CGRect(
                        x: col * tileWidth,
                        y: row * tileHeight,
                        width: tileWidth,
                        height: tileHeight
                    )
                    if let cropped = sheet.cropping(to: rect) {
                        results.append(
                            GalleryPicture(
                                name: "Real Picture \(index)",
                                systemImage: "photo",
                                content: .image(cropped)
                            )
                        )
                        index += 1
                    }
                }
            }
        }

        if let chibi = loadCGImage(named: "chibigirl") {
            let columns = 5
            let rows = 2
            let tileWidth = chibi.width / columns
            let tileHeight = chibi.height / rows

            var index = 1
            for row in 0..<rows {
                for col in 0..<columns {
                    let rect = CGRect(
                        x: col * tileWidth,
                        y: row * tileHeight,
                        width: tileWidth,
                        height: tileHeight
                    )
                    if let cropped = chibi.cropping(to: rect) {
                        results.append(
                            GalleryPicture(
                                name: "Chibi Girl \(index)",
                                systemImage: "photo",
                                content: .image(cropped)
                            )
                        )
                        index += 1
                    }
                }
            }
        }
      
      if let chibi = loadCGImage(named: "witch") {
          let columns = 5
          let rows = 2
          let tileWidth = chibi.width / columns
          let tileHeight = chibi.height / rows

          var index = 1
          for row in 0..<rows {
              for col in 0..<columns {
                  let rect = CGRect(
                      x: col * tileWidth,
                      y: row * tileHeight,
                      width: tileWidth,
                      height: tileHeight
                  )
                  if let cropped = chibi.cropping(to: rect) {
                      results.append(
                          GalleryPicture(
                              name: "Chibi Witch \(index)",
                              systemImage: "photo",
                              content: .image(cropped)
                          )
                      )
                      index += 1
                  }
              }
          }
      }

        return results
    }

    private static func loadCGImage(named name: String) -> CGImage? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "png")
        ]

        for url in candidates.compactMap({ $0 }) {
            if let image = cgImage(from: url) { return image }
        }

        if let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil),
           let match = urls.first(where: { $0.lastPathComponent == "\(name).png" }),
           let image = cgImage(from: match) {
            return image
        }

        // Fallback: recursively scan bundled resources by filename.
        if let resourcePath = Bundle.main.resourcePath {
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                for case let path as String in enumerator {
                    if (path as NSString).lastPathComponent == "\(name).png" {
                        let url = URL(fileURLWithPath: resourcePath).appendingPathComponent(path)
                        if let image = cgImage(from: url) { return image }
                    }
                }
            }
        }

        return nil
    }

    private static func cgImage(from url: URL) -> CGImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return image
        }

        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
        #elseif canImport(AppKit)
        guard let data = try? Data(contentsOf: url), let nsImage = NSImage(data: data) else { return nil }
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }

    private static func renderDrawing(_ draw: (CGContext, CGSize) -> Void, size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
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

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(max(4, size.width * 0.01))
        context.setLineCap(.round)
        context.setLineJoin(.round)

        draw(context, size)
        return context.makeImage()
    }

    private static let drawnPictures: [GalleryPicture] = [
        GalleryPicture(name: "Dog", systemImage: "dog", content: .drawing { ctx, s in
            let c = CGPoint(x: s.width * 0.5, y: s.height * 0.55)
            ctx.strokeEllipse(in: CGRect(x: c.x - s.width * 0.22, y: c.y - s.height * 0.18, width: s.width * 0.44, height: s.height * 0.36))
            ctx.strokeEllipse(in: CGRect(x: c.x - s.width * 0.14, y: c.y - s.height * 0.42, width: s.width * 0.28, height: s.height * 0.26))
            ctx.strokeEllipse(in: CGRect(x: c.x - s.width * 0.28, y: c.y - s.height * 0.45, width: s.width * 0.12, height: s.height * 0.18))
            ctx.strokeEllipse(in: CGRect(x: c.x + s.width * 0.16, y: c.y - s.height * 0.45, width: s.width * 0.12, height: s.height * 0.18))
            ctx.fillEllipse(in: CGRect(x: c.x - s.width * 0.05, y: c.y - s.height * 0.33, width: s.width * 0.03, height: s.width * 0.03))
            ctx.fillEllipse(in: CGRect(x: c.x + s.width * 0.02, y: c.y - s.height * 0.33, width: s.width * 0.03, height: s.width * 0.03))
            ctx.strokeEllipse(in: CGRect(x: c.x - s.width * 0.03, y: c.y - s.height * 0.28, width: s.width * 0.06, height: s.width * 0.05))
            ctx.move(to: CGPoint(x: c.x, y: c.y - s.height * 0.23))
            ctx.addLine(to: CGPoint(x: c.x, y: c.y - s.height * 0.18))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Cat", systemImage: "cat", content: .drawing { ctx, s in
            let c = CGPoint(x: s.width * 0.5, y: s.height * 0.55)
            let head = CGRect(x: c.x - s.width * 0.18, y: c.y - s.height * 0.32, width: s.width * 0.36, height: s.height * 0.30)
            ctx.strokeEllipse(in: head)
            ctx.move(to: CGPoint(x: head.minX + head.width * 0.15, y: head.minY + 10))
            ctx.addLine(to: CGPoint(x: head.minX - s.width * 0.04, y: head.minY - s.height * 0.08))
            ctx.addLine(to: CGPoint(x: head.minX + head.width * 0.4, y: head.minY + head.height * 0.15))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: head.maxX - head.width * 0.15, y: head.minY + 10))
            ctx.addLine(to: CGPoint(x: head.maxX + s.width * 0.04, y: head.minY - s.height * 0.08))
            ctx.addLine(to: CGPoint(x: head.maxX - head.width * 0.4, y: head.minY + head.height * 0.15))
            ctx.strokePath()
            ctx.fillEllipse(in: CGRect(x: c.x - s.width * 0.07, y: c.y - s.height * 0.22, width: s.width * 0.03, height: s.width * 0.03))
            ctx.fillEllipse(in: CGRect(x: c.x + s.width * 0.04, y: c.y - s.height * 0.22, width: s.width * 0.03, height: s.width * 0.03))
            ctx.strokeEllipse(in: CGRect(x: c.x - s.width * 0.18, y: c.y - s.height * 0.05, width: s.width * 0.36, height: s.height * 0.28))
            ctx.move(to: CGPoint(x: c.x - s.width * 0.18, y: c.y - s.height * 0.12))
            ctx.addLine(to: CGPoint(x: c.x - s.width * 0.30, y: c.y - s.height * 0.14))
            ctx.move(to: CGPoint(x: c.x + s.width * 0.18, y: c.y - s.height * 0.12))
            ctx.addLine(to: CGPoint(x: c.x + s.width * 0.30, y: c.y - s.height * 0.14))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Robot Hero", systemImage: "figure.strengthtraining.traditional", content: .drawing { ctx, s in
            let head = CGRect(x: s.width * 0.38, y: s.height * 0.12, width: s.width * 0.24, height: s.height * 0.18)
            ctx.stroke(head)
            ctx.stroke(CGRect(x: s.width * 0.32, y: s.height * 0.30, width: s.width * 0.36, height: s.height * 0.30))
            ctx.stroke(CGRect(x: s.width * 0.18, y: s.height * 0.33, width: s.width * 0.12, height: s.height * 0.22))
            ctx.stroke(CGRect(x: s.width * 0.70, y: s.height * 0.33, width: s.width * 0.12, height: s.height * 0.22))
            ctx.stroke(CGRect(x: s.width * 0.36, y: s.height * 0.60, width: s.width * 0.11, height: s.height * 0.25))
            ctx.stroke(CGRect(x: s.width * 0.53, y: s.height * 0.60, width: s.width * 0.11, height: s.height * 0.25))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.44, y: s.height * 0.18, width: s.width * 0.04, height: s.width * 0.04))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.52, y: s.height * 0.18, width: s.width * 0.04, height: s.width * 0.04))
            ctx.move(to: CGPoint(x: s.width * 0.43, y: s.height * 0.25))
            ctx.addLine(to: CGPoint(x: s.width * 0.57, y: s.height * 0.25))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Robot Cat", systemImage: "teddybear", content: .drawing { ctx, s in
            let body = CGRect(x: s.width * 0.28, y: s.height * 0.35, width: s.width * 0.44, height: s.height * 0.40)
            ctx.strokeEllipse(in: body)
            let head = CGRect(x: s.width * 0.30, y: s.height * 0.12, width: s.width * 0.40, height: s.height * 0.34)
            ctx.strokeEllipse(in: head)
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.34, y: s.height * 0.43, width: s.width * 0.32, height: s.height * 0.24))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.40, y: s.height * 0.24, width: s.width * 0.05, height: s.width * 0.05))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.55, y: s.height * 0.24, width: s.width * 0.05, height: s.width * 0.05))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.47, y: s.height * 0.31, width: s.width * 0.06, height: s.width * 0.04))
            ctx.move(to: CGPoint(x: s.width * 0.50, y: s.height * 0.35))
            ctx.addLine(to: CGPoint(x: s.width * 0.50, y: s.height * 0.41))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Fish", systemImage: "fish", content: .drawing { ctx, s in
            let body = CGRect(x: s.width * 0.18, y: s.height * 0.32, width: s.width * 0.46, height: s.height * 0.36)
            ctx.strokeEllipse(in: body)
            ctx.move(to: CGPoint(x: s.width * 0.64, y: s.height * 0.50))
            ctx.addLine(to: CGPoint(x: s.width * 0.84, y: s.height * 0.34))
            ctx.addLine(to: CGPoint(x: s.width * 0.84, y: s.height * 0.66))
            ctx.closePath()
            ctx.strokePath()
            ctx.fillEllipse(in: CGRect(x: s.width * 0.30, y: s.height * 0.45, width: s.width * 0.04, height: s.width * 0.04))
        }),
        GalleryPicture(name: "Butterfly", systemImage: "butterfly", content: .drawing { ctx, s in
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.12, y: s.height * 0.20, width: s.width * 0.34, height: s.height * 0.28))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.54, y: s.height * 0.20, width: s.width * 0.34, height: s.height * 0.28))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.16, y: s.height * 0.50, width: s.width * 0.30, height: s.height * 0.26))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.54, y: s.height * 0.50, width: s.width * 0.30, height: s.height * 0.26))
            ctx.move(to: CGPoint(x: s.width * 0.50, y: s.height * 0.18))
            ctx.addLine(to: CGPoint(x: s.width * 0.50, y: s.height * 0.78))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Car", systemImage: "car", content: .drawing { ctx, s in
            ctx.stroke(CGRect(x: s.width * 0.12, y: s.height * 0.45, width: s.width * 0.76, height: s.height * 0.18))
            ctx.move(to: CGPoint(x: s.width * 0.28, y: s.height * 0.45))
            ctx.addLine(to: CGPoint(x: s.width * 0.38, y: s.height * 0.30))
            ctx.addLine(to: CGPoint(x: s.width * 0.62, y: s.height * 0.30))
            ctx.addLine(to: CGPoint(x: s.width * 0.72, y: s.height * 0.45))
            ctx.strokePath()
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.22, y: s.height * 0.58, width: s.width * 0.14, height: s.width * 0.14))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.64, y: s.height * 0.58, width: s.width * 0.14, height: s.width * 0.14))
        }),
        GalleryPicture(name: "House", systemImage: "house", content: .drawing { ctx, s in
            let house = CGRect(x: s.width * 0.22, y: s.height * 0.40, width: s.width * 0.56, height: s.height * 0.40)
            ctx.stroke(house)
            ctx.move(to: CGPoint(x: house.minX, y: house.minY))
            ctx.addLine(to: CGPoint(x: s.width * 0.5, y: s.height * 0.15))
            ctx.addLine(to: CGPoint(x: house.maxX, y: house.minY))
            ctx.closePath()
            ctx.strokePath()
            ctx.stroke(CGRect(x: s.width * 0.44, y: s.height * 0.58, width: s.width * 0.12, height: s.height * 0.22))
        }),
        GalleryPicture(name: "Tree", systemImage: "tree", content: .drawing { ctx, s in
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.30, y: s.height * 0.12, width: s.width * 0.40, height: s.height * 0.34))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.18, y: s.height * 0.28, width: s.width * 0.34, height: s.height * 0.30))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.48, y: s.height * 0.28, width: s.width * 0.34, height: s.height * 0.30))
            ctx.stroke(CGRect(x: s.width * 0.45, y: s.height * 0.56, width: s.width * 0.10, height: s.height * 0.28))
        }),
        GalleryPicture(name: "Flower", systemImage: "camera.macro", content: .drawing { ctx, s in
            let center = CGPoint(x: s.width * 0.5, y: s.height * 0.38)
            for i in 0..<6 {
                let angle = CGFloat(i) * (.pi * 2 / 6)
                let p = CGPoint(x: center.x + cos(angle) * s.width * 0.14, y: center.y + sin(angle) * s.width * 0.14)
                ctx.strokeEllipse(in: CGRect(x: p.x - s.width * 0.09, y: p.y - s.width * 0.09, width: s.width * 0.18, height: s.width * 0.18))
            }
            ctx.strokeEllipse(in: CGRect(x: center.x - s.width * 0.08, y: center.y - s.width * 0.08, width: s.width * 0.16, height: s.width * 0.16))
            ctx.move(to: CGPoint(x: s.width * 0.5, y: s.height * 0.54))
            ctx.addLine(to: CGPoint(x: s.width * 0.5, y: s.height * 0.86))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Sun & Cloud", systemImage: "sun.max", content: .drawing { ctx, s in
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.12, y: s.height * 0.12, width: s.width * 0.22, height: s.width * 0.22))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.36, y: s.height * 0.46, width: s.width * 0.30, height: s.height * 0.18))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.52, y: s.height * 0.38, width: s.width * 0.24, height: s.height * 0.20))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.26, y: s.height * 0.40, width: s.width * 0.22, height: s.height * 0.18))
        }),
        GalleryPicture(name: "Rocket", systemImage: "airplane", content: .drawing { ctx, s in
            ctx.move(to: CGPoint(x: s.width * 0.5, y: s.height * 0.10))
            ctx.addLine(to: CGPoint(x: s.width * 0.62, y: s.height * 0.32))
            ctx.addLine(to: CGPoint(x: s.width * 0.62, y: s.height * 0.70))
            ctx.addLine(to: CGPoint(x: s.width * 0.38, y: s.height * 0.70))
            ctx.addLine(to: CGPoint(x: s.width * 0.38, y: s.height * 0.32))
            ctx.closePath()
            ctx.strokePath()
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.45, y: s.height * 0.36, width: s.width * 0.10, height: s.width * 0.10))
            ctx.move(to: CGPoint(x: s.width * 0.38, y: s.height * 0.55))
            ctx.addLine(to: CGPoint(x: s.width * 0.25, y: s.height * 0.72))
            ctx.addLine(to: CGPoint(x: s.width * 0.38, y: s.height * 0.68))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: s.width * 0.62, y: s.height * 0.55))
            ctx.addLine(to: CGPoint(x: s.width * 0.75, y: s.height * 0.72))
            ctx.addLine(to: CGPoint(x: s.width * 0.62, y: s.height * 0.68))
            ctx.strokePath()
        }),
        GalleryPicture(name: "Dinosaur", systemImage: "lizard", content: .drawing { ctx, s in
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.30, y: s.height * 0.30, width: s.width * 0.34, height: s.height * 0.24))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.56, y: s.height * 0.22, width: s.width * 0.18, height: s.height * 0.16))
            ctx.move(to: CGPoint(x: s.width * 0.30, y: s.height * 0.42))
            ctx.addLine(to: CGPoint(x: s.width * 0.14, y: s.height * 0.34))
            ctx.addLine(to: CGPoint(x: s.width * 0.18, y: s.height * 0.50))
            ctx.strokePath()
            ctx.stroke(CGRect(x: s.width * 0.36, y: s.height * 0.54, width: s.width * 0.07, height: s.height * 0.18))
            ctx.stroke(CGRect(x: s.width * 0.50, y: s.height * 0.54, width: s.width * 0.07, height: s.height * 0.18))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.67, y: s.height * 0.27, width: s.width * 0.03, height: s.width * 0.03))
        }),
        GalleryPicture(name: "Rabbit", systemImage: "hare", content: .drawing { ctx, s in
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.34, y: s.height * 0.34, width: s.width * 0.32, height: s.height * 0.28))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.36, y: s.height * 0.10, width: s.width * 0.10, height: s.height * 0.28))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.54, y: s.height * 0.10, width: s.width * 0.10, height: s.height * 0.28))
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.28, y: s.height * 0.50, width: s.width * 0.44, height: s.height * 0.30))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.43, y: s.height * 0.44, width: s.width * 0.03, height: s.width * 0.03))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.54, y: s.height * 0.44, width: s.width * 0.03, height: s.width * 0.03))
        }),
        GalleryPicture(name: "Star", systemImage: "star", content: .drawing { ctx, s in
            let cx = s.width * 0.5, cy = s.height * 0.5
            let outer = s.width * 0.32, inner = s.width * 0.13
            var points: [CGPoint] = []
            for i in 0..<10 {
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let r = i % 2 == 0 ? outer : inner
                points.append(CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r))
            }
            ctx.move(to: points[0])
            for p in points.dropFirst() { ctx.addLine(to: p) }
            ctx.closePath()
            ctx.strokePath()
        }),
        GalleryPicture(name: "Balloon", systemImage: "balloon", content: .drawing { ctx, s in
            ctx.strokeEllipse(in: CGRect(x: s.width * 0.34, y: s.height * 0.12, width: s.width * 0.32, height: s.height * 0.42))
            ctx.move(to: CGPoint(x: s.width * 0.5, y: s.height * 0.54))
            ctx.addLine(to: CGPoint(x: s.width * 0.5, y: s.height * 0.86))
            ctx.strokePath()
        })
    ]
}
