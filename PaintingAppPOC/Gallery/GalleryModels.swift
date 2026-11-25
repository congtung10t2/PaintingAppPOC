import CoreGraphics
import Foundation

enum GalleryPictureContent {
    case drawing((CGContext, CGSize) -> Void)
    case image(CGImage)
}

struct GalleryPicture: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let systemImage: String
    let content: GalleryPictureContent

    // Equate and hash by `id` only: `content` holds a closure / CGImage which are
    // neither Equatable nor Hashable, so a synthesized conformance is impossible.
    static func == (lhs: GalleryPicture, rhs: GalleryPicture) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
