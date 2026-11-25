import SwiftUI

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    var isEraser: Bool = false
}

enum PaintTool: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case brush = "Brush"
    case fill = "Fill"
    case eraser = "Eraser"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pencil: return "pencil.tip"
        case .brush: return "paintbrush.pointed"
        case .fill: return "drop.fill"
        case .eraser: return "eraser"
        }
    }
}
