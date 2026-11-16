import CoreGraphics
import Foundation

enum GalleryPictureContent {
    case drawing((CGContext, CGSize) -> Void)
    case image(CGImage)
}

struct GalleryPicture: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let content: GalleryPictureContent
}
