import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct PaintingScreen: View {
    private struct HistoryEntry {
        let strokes: [Stroke]
        let workingCGImage: CGImage?
    }

    @State private var strokes: [Stroke] = []
    @State private var currentStroke: Stroke?
    @State private var selectedColor: Color = .red
    @State private var brushSize: CGFloat = 12
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var backgroundImage: Image?
    @State private var workingCGImage: CGImage?
    @State private var originalCGImage: CGImage?
    @State private var isImportingFile = false
    @State private var isShowingTransformer = false
    @State private var transformerImage: CGImage?
    @State private var isShowingGallery = false
    @State private var isShowingExporter = false
    @State private var exportDocument: PNGDocument?
    @State private var selectedTool: PaintTool = .brush
    @State private var canvasScale: CGFloat = 1.0
    @State private var lastCanvasScale: CGFloat = 1.0
    @State private var canvasContainerSize: CGSize = .zero
    @State private var history: [HistoryEntry] = []
    @State private var redoStack: [HistoryEntry] = []
    @State private var saveMessage: String?
    @State private var strokesLayerCGImage: CGImage?
    @State private var renderGeneration: Int = 0
    /// `true` when the currently selected background image is essentially
    /// black-and-white (no color), so the "Transform with AI" menu item is hidden.
    @State private var isSelectedImageGrayscale = false

    private let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .blue, .purple, .pink, .brown, .black, .white
    ]
    private let imageProcessor = ImageProcessor()

    var body: some View {
        VStack(spacing: 0) {
            header
            canvas
            toolbar
        }
        .background(backgroundColor)
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .fileExporter(
            isPresented: $isShowingExporter,
            document: exportDocument,
            contentType: .png,
            defaultFilename: "KidsPaint\(Date())"
        ) { _ in }
        .onChange(of: selectedPhotoItem) { _, newItem in
          Task(priority: .userInitiated) {
            await loadPhoto(from: newItem)
          }
        }
        .sheet(isPresented: $isShowingGallery) {
            GalleryView(
                onTransformResult: applyTransformResult,
                convert: makeGalleryCGImage
            )
        }
        .sheet(isPresented: $isShowingTransformer) {
            ColoringTransformer(
                inputImage: transformerImage,
                onOriginal: { original in
                    applyTransformResult(original)
                },
                onComplete: { result in
                    applyTransformResult(result)
                }
            )
        }
        .alert("Save", isPresented: Binding(
            get: { saveMessage != nil },
            set: { if !$0 { saveMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveMessage = nil }
        } message: {
            Text(saveMessage ?? "")
        }
    }

    private var backgroundColor: Color {
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.gray.opacity(0.15)
        #endif
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                toolButton(.pencil)
                toolButton(.brush)
                toolButton(.fill)
                toolButton(.eraser)
            }

            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(history.isEmpty)

          Button {
              redo()
          } label: {
              Image(systemName: "arrow.uturn.forward")
          }
          .buttonStyle(.bordered)
          .disabled(redoStack.isEmpty)

            Spacer()

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
           

            Menu {
                Button {
                    isShowingGallery = true
                } label: {
                    Label("Gallery", systemImage: "square.grid.2x2")
                }

                if !isSelectedImageGrayscale {
                    Button {
                        transformerImage = originalCGImage
                        isShowingTransformer = true
                    } label: {
                        Label("Transform with AI", systemImage: "wand.and.stars")
                    }
                }

                Button {
                    isImportingFile = true
                } label: {
                    Label("Choose File", systemImage: "folder")
                }

                Button {
                    savePicture()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Divider()

                Button {
                    undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(history.isEmpty)

                Button {
                    redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(redoStack.isEmpty)

                Button {
                    pushHistory()
                    strokes.removeAll()
                    currentStroke = nil
                    rebuildStrokesLayer()
                } label: {
                    Label("Clear Drawing", systemImage: "trash")
                }
                .disabled(strokes.isEmpty && currentStroke == nil)

                Button {
                    resetPainting()
                } label: {
                    Label("Reset Painting", systemImage: "arrow.counterclockwise.circle")
                }
                .disabled(strokes.isEmpty && currentStroke == nil && history.isEmpty && workingCGImage == originalCGImage)

                if backgroundImage != nil {
                    Button {
                        pushHistory()
                        backgroundImage = nil
                        workingCGImage = nil
                        originalCGImage = nil
                        selectedPhotoItem = nil
                        strokesLayerCGImage = nil
                        isSelectedImageGrayscale = false
                    } label: {
                        Label("Remove Picture", systemImage: "xmark.circle")
                    }
                }

                Divider()

                Button {
                    canvasScale = min(5.0, canvasScale + 0.25)
                    lastCanvasScale = canvasScale
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }

                Button {
                    canvasScale = max(1.0, canvasScale - 0.25)
                    lastCanvasScale = canvasScale
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }

                Button {
                    canvasScale = 1.0
                    lastCanvasScale = 1.0
                } label: {
                    Label("Reset Zoom", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func toolButton(_ tool: PaintTool) -> some View {
        Button {
            // Update brush size first to keep it within the new tool's range
            if tool == .pencil {
                brushSize = min(max(brushSize, 1), 8)
            } else if tool == .brush || tool == .eraser {
                brushSize = min(max(brushSize, 4), 40)
            }
            selectedTool = tool
        } label: {
            Image(systemName: tool.systemImage)
        }
        .buttonStyle(.bordered)
        .tint(selectedTool == tool ? .accentColor : .gray)
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white)

                if let backgroundImage {
                    backgroundImage
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                if let strokesLayerCGImage {
                    Image(decorative: strokesLayerCGImage, scale: 1)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                Canvas { context, _ in
                    if let currentStroke {
                        draw(currentStroke, in: &context)
                    }
                }
                .contentShape(Rectangle())
                .highPriorityGesture(canvasGesture(in: geo.size), including: .all)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(canvasScale)
            #if os(macOS)
            .modifier(ScrollWheelZoomModifier(scale: $canvasScale, lastScale: $lastCanvasScale))
            #else
            .simultaneousGesture(magnificationGesture)
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .clipped()
            .onAppear {
                if canvasContainerSize != geo.size {
                    canvasContainerSize = geo.size
                    strokesLayerCGImage = nil
                    renderGeneration += 1
                    rebuildStrokesLayer()
                }
            }
            .onChange(of: geo.size) { _, newSize in
                guard canvasContainerSize != newSize else { return }
                canvasContainerSize = newSize
                strokesLayerCGImage = nil
                renderGeneration += 1
                rebuildStrokesLayer()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var toolbar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(palette, id: \.self) { color in
                        colorButton(for: color)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: selectedTool == .pencil ? 6 : 8))
                    .foregroundStyle(.secondary)
                Slider(value: $brushSize, in: brushSizeRange)
                Image(systemName: "circle.fill")
                    .font(.system(size: selectedTool == .pencil ? 14 : 20))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .frame(height: 30)
            .opacity(selectedTool != .fill ? 1 : 0)
            .disabled(selectedTool == .fill)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var brushSizeRange: ClosedRange<CGFloat> {
        switch selectedTool {
        case .pencil:
            return 1...8
        case .brush, .eraser:
            return 4...40
        case .fill:
            return 4...40
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard value.isFinite && value > 0 else { return }
                let newScale = lastCanvasScale * value
                canvasScale = min(max(newScale, 1.0), 5.0)
            }
            .onEnded { _ in
                lastCanvasScale = canvasScale
            }
    }

    private func colorButton(for color: Color) -> some View {
        let isSelected = selectedColor == color
        let checkmarkColor: Color = (color == .yellow || color == .mint || color == .white) ? .black : .white

        return Button {
            selectedColor = color
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(checkmarkColor)
                }
                Circle()
                    .stroke(Color.primary.opacity(isSelected ? 0.4 : 0.15), lineWidth: 3)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private func canvasGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard selectedTool == .pencil || selectedTool == .brush || selectedTool == .eraser else { return }
                guard value.location.x >= 0, value.location.y >= 0,
                      value.location.x <= containerSize.width, value.location.y <= containerSize.height else { return }
                let point = adjustedPoint(value.location, in: containerSize)
                if currentStroke == nil {
                    currentStroke = Stroke(
                        points: [point],
                        color: selectedColor,
                        lineWidth: brushSize / canvasScale,
                        isEraser: selectedTool == .eraser
                    )
                    return
                }

                guard var points = currentStroke?.points, let last = points.last else { return }
                let minDistance: CGFloat = max(1.0, (brushSize / canvasScale) * 0.15)
                let dx = point.x - last.x
                let dy = point.y - last.y
                if (dx * dx + dy * dy) < (minDistance * minDistance) { return }
                points.append(point)
                currentStroke?.points = points
            }
            .onEnded { value in
                switch selectedTool {
                case .pencil, .brush:
                    if let stroke = currentStroke {
                        pushHistory()
                        strokes.append(stroke)
                        commitStrokeToLayer(stroke)
                    }
                    currentStroke = nil
                case .eraser:
                    if let stroke = currentStroke {
                        applyEraserStroke(stroke, in: containerSize)
                    }
                    currentStroke = nil
                case .fill:
                    let point = adjustedPoint(value.location, in: containerSize)
                    performFill(at: point, in: containerSize)
                }
            }
    }

    private func adjustedPoint(_ location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(location.x, 0), size.width),
            y: min(max(location.y, 0), size.height)
        )
    }

    private func draw(_ stroke: Stroke, in context: inout GraphicsContext) {
        var path = Path()
        guard let first = stroke.points.first else { return }

        let isDot = stroke.points.count == 1
        if isDot {
            let radius = stroke.lineWidth / 2
            let rect = CGRect(x: first.x - radius, y: first.y - radius, width: stroke.lineWidth, height: stroke.lineWidth)
            path.addEllipse(in: rect)
        } else {
            path.move(to: first)
            for point in stroke.points.dropFirst() {
                path.addLine(to: point)
            }
        }

        if stroke.isEraser {
            var eraserContext = context
            eraserContext.blendMode = .destinationOut
            if isDot {
                eraserContext.fill(path, with: .color(.black))
            } else {
                eraserContext.stroke(
                    path,
                    with: .color(.black),
                    style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
            return
        }

        if isDot {
            context.fill(path, with: .color(stroke.color))
        } else {
            context.stroke(
                path,
                with: .color(stroke.color),
                style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// Builds the line-art `CGImage` for a gallery picture at 1024×1024, applying
    /// the black-and-white conversion for real `.image` pictures (kept here in the
    /// presenter, since `ImageProcessor` is a freely-instantiable struct but the
    /// B&W policy belongs to the paint screen). Returns `nil` when no image is
    /// produced.
    private func makeGalleryCGImage(from picture: GalleryPicture) -> CGImage? {
        return GalleryCatalog.makeImage(for: picture, size: CGSize(width: 1024, height: 1024))
    }

    private func selectGalleryPicture(_ picture: GalleryPicture) {
        guard let finalCG = makeGalleryCGImage(from: picture) else { return }
        isSelectedImageGrayscale = imageProcessor.isBlackAndWhite(finalCG)
        originalCGImage = finalCG
        workingCGImage = finalCG
        backgroundImage = Image(decorative: finalCG, scale: 1.0)
        strokes.removeAll()
        currentStroke = nil
        selectedPhotoItem = nil
        canvasScale = 1.0
        lastCanvasScale = 1.0
        history.removeAll()
        redoStack.removeAll()
        strokesLayerCGImage = nil
    }

    /// Applies a transform result forwarded from the `ColoringTransformer` (after
    /// the user taps OK) and dismisses the gallery sheet. Mirrors
    /// `selectGalleryPicture`'s canvas reset so the painted state starts fresh on
    /// the new image.
    private func applyTransformResult(_ cg: CGImage) {
        isSelectedImageGrayscale = imageProcessor.isBlackAndWhite(cg)
        originalCGImage = cg
        workingCGImage = cg
        backgroundImage = Image(decorative: cg, scale: 1.0)
        strokes.removeAll()
        currentStroke = nil
        selectedPhotoItem = nil
        canvasScale = 1.0
        lastCanvasScale = 1.0
        history.removeAll()
        redoStack.removeAll()
        strokesLayerCGImage = nil
        isShowingGallery = false
        isShowingTransformer = false
    }
@MainActor
  private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
          if let data = try? await item.loadTransferable(type: Data.self) {
            prepareForTransform(from: data)
          }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let data = try? Data(contentsOf: url) {
            prepareForTransform(from: data) 
        }
    }

    @MainActor
    private func prepareForTransform(from data: Data)  {
        guard let cgImage = imageProcessor.cgImage(from: data) else { return }
        isSelectedImageGrayscale = imageProcessor.isBlackAndWhite(cgImage)
        // If the selected picture is already black-and-white, skip the "Transform
        // with AI" popup and place it directly on the canvas.
        if isSelectedImageGrayscale {
            setBackground(from: data)
            return
        }
        transformerImage = cgImage
        isShowingTransformer = true
    }

    @MainActor
    private func setBackground(from data: Data) {
        guard let cgImage = imageProcessor.cgImage(from: data) else { return }
        isSelectedImageGrayscale = imageProcessor.isBlackAndWhite(cgImage)
        originalCGImage = cgImage
        workingCGImage = cgImage
        backgroundImage = Image(decorative: cgImage, scale: 1.0)
        strokes.removeAll()
        currentStroke = nil
        canvasScale = 1.0
        lastCanvasScale = 1.0
        history.removeAll()
        redoStack.removeAll()
        strokesLayerCGImage = nil
    }

    private func performFill(at location: CGPoint, in containerSize: CGSize) {
        let baseImage = compositeImageForEditing() ?? workingCGImage
        guard let cgImage = baseImage else { return }

        let imageArea = CGRect(origin: .zero, size: containerSize).insetBy(dx: 12, dy: 12)
        let fittedRect = imageProcessor.aspectFitRect(
            imageSize: CGSize(width: cgImage.width, height: cgImage.height),
            in: imageArea
        )
        guard fittedRect.insetBy(dx: 0.5, dy: 0.5).contains(location) else { return }

        let normalizedX = (location.x - fittedRect.minX) / fittedRect.width
        let normalizedY = (location.y - fittedRect.minY) / fittedRect.height
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else { return }

        let px = min(max(Int(normalizedX * CGFloat(cgImage.width)), 0), cgImage.width - 1)
        let py = min(max(Int(normalizedY * CGFloat(cgImage.height)), 0), cgImage.height - 1)

        if let filled = imageProcessor.floodFill(
            cgImage: cgImage,
            start: CGPoint(x: px, y: py),
            fillColor: imageProcessor.rgba(from: selectedColor),
            tolerance: 24
        ) {
            pushHistory()
            isSelectedImageGrayscale = imageProcessor.isBlackAndWhite(filled)
            workingCGImage = filled
            backgroundImage = Image(decorative: filled, scale: 1.0)
            strokes.removeAll()
            currentStroke = nil
            strokesLayerCGImage = nil
        }
    }

    @MainActor
    private func compositeImageForEditing() -> CGImage? {
        // Bake current background and strokes so fill can interact with painted content.
        if workingCGImage == nil && strokes.isEmpty { return nil }

        let size = exportCanvasSize
        let exportStrokes = transformedStrokes(for: size)
        let exportView = CanvasExportView(
            workingCGImage: workingCGImage,
            strokes: exportStrokes,
            size: size
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.cgImage
        #elseif canImport(AppKit)
        return renderer.nsImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }

    private func pushHistory() {
        history.append(HistoryEntry(strokes: strokes, workingCGImage: workingCGImage))
        if history.count > 30 {
            history.removeFirst(history.count - 30)
        }
        redoStack.removeAll()
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        redoStack.append(last)
        strokes = last.strokes
        currentStroke = nil
        workingCGImage = last.workingCGImage
        if let cg = last.workingCGImage {
            backgroundImage = Image(decorative: cg, scale: 1.0)
        } else {
            backgroundImage = nil
        }
        rebuildStrokesLayer()
    }

    private func redo() {
        guard let entry = redoStack.popLast() else { return }
        history.append(entry)
        strokes = entry.strokes
        currentStroke = nil
        workingCGImage = entry.workingCGImage
        if let cg = entry.workingCGImage {
            backgroundImage = Image(decorative: cg, scale: 1.0)
        } else {
            backgroundImage = nil
        }
        rebuildStrokesLayer()
    }

    @MainActor
    private func applyEraserStroke(_ stroke: Stroke, in containerSize: CGSize) {
        // Erase drawn strokes on the stroke layer and also erase fills/paint on the bitmap image.
        pushHistory()

        // Keep eraser stroke for vector stroke-layer erasing.
        strokes.append(stroke)
        commitStrokeToLayer(stroke)

        // If there is no bitmap yet, create one from current composite so fills on blank canvas can be erased.
        var baseImage = workingCGImage ?? compositeImageForEditing()
        guard let cg = baseImage else { return }

        let imageArea = CGRect(origin: .zero, size: containerSize).insetBy(dx: 12, dy: 12)
        let fittedRect = imageProcessor.aspectFitRect(
            imageSize: CGSize(width: cg.width, height: cg.height),
            in: imageArea
        )
        guard fittedRect.width > 0, fittedRect.height > 0 else { return }

        let sx = CGFloat(cg.width) / fittedRect.width
        let sy = CGFloat(cg.height) / fittedRect.height
        let imagePoints = stroke.points.map { p in
            CGPoint(x: (p.x - fittedRect.minX) * sx, y: (p.y - fittedRect.minY) * sy)
        }
        let lineWidth = stroke.lineWidth * ((sx + sy) / 2)

        if let erased = imageProcessor.applyStroke(points: imagePoints, lineWidth: lineWidth, color: (255, 255, 255, 255), to: cg) {
            isSelectedImageGrayscale = imageProcessor.isBlackAndWhite(erased)
            workingCGImage = erased
            backgroundImage = Image(decorative: erased, scale: 1.0)
        }
    }

    private func rebuildStrokesLayer() {
        guard canvasContainerSize.width > 0, canvasContainerSize.height > 0 else {
            strokesLayerCGImage = nil
            return
        }
        let size = canvasContainerSize
        let strokesToRender = strokes
        let processor = imageProcessor
        DispatchQueue.global(qos: .userInitiated).async {
            let layer = processor.renderStrokesLayer(size: size, strokes: strokesToRender)
            DispatchQueue.main.async {
                // Apply only if state still matches what we rendered for.
                if self.canvasContainerSize == size {
                    self.strokesLayerCGImage = layer
                }
            }
        }
    }

    private func commitStrokeToLayer(_ stroke: Stroke) {
        guard canvasContainerSize.width > 0, canvasContainerSize.height > 0 else { return }
        // Immediate incremental render to avoid end-of-stroke flicker.
        if let updated = imageProcessor.renderStrokesLayer(size: canvasContainerSize, strokes: [stroke], baseLayer: strokesLayerCGImage) {
            strokesLayerCGImage = updated
        } else {
            rebuildStrokesLayer()
        }
    }

    private func resetPainting() {
        pushHistory()
        workingCGImage = originalCGImage
        isSelectedImageGrayscale = originalCGImage.map { imageProcessor.isBlackAndWhite($0) } ?? false
        if let cg = originalCGImage {
            backgroundImage = Image(decorative: cg, scale: 1.0)
        } else {
            backgroundImage = nil
        }
        strokes.removeAll()
        currentStroke = nil
        strokesLayerCGImage = nil
    }

    @MainActor
    private func savePicture() {
        let exportSize = exportCanvasSize
        let exportStrokes = transformedStrokes(for: exportSize)

        let exportView = CanvasExportView(
            workingCGImage: workingCGImage,
            strokes: exportStrokes,
            size: exportSize
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 1

        #if canImport(UIKit)
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        saveMessage = "Saved to Photos"
        #elseif canImport(AppKit)
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }
        exportDocument = PNGDocument(data: data)
        isShowingExporter = true
        #endif
    }

    private var exportCanvasSize: CGSize {
        if let cg = workingCGImage {
            return CGSize(width: cg.width, height: cg.height)
        }
        let w = max(canvasContainerSize.width, 1)
        let h = max(canvasContainerSize.height, 1)
        return CGSize(width: w * 2, height: h * 2)
    }

    private func transformedStrokes(for exportSize: CGSize) -> [Stroke] {
        if let cg = workingCGImage, canvasContainerSize.width > 0, canvasContainerSize.height > 0 {
            let imageArea = CGRect(origin: .zero, size: canvasContainerSize).insetBy(dx: 12, dy: 12)
            let fittedRect = imageProcessor.aspectFitRect(
                imageSize: CGSize(width: cg.width, height: cg.height),
                in: imageArea
            )
            guard fittedRect.width > 0, fittedRect.height > 0 else { return strokes }
            let sx = exportSize.width / fittedRect.width
            let sy = exportSize.height / fittedRect.height
            return strokes.map { stroke in
                var s = stroke
                s.points = stroke.points.map { p in
                    CGPoint(x: (p.x - fittedRect.minX) * sx, y: (p.y - fittedRect.minY) * sy)
                }
                s.lineWidth = stroke.lineWidth * ((sx + sy) / 2)
                return s
            }
        } else {
            let baseW = max(canvasContainerSize.width, 1)
            let baseH = max(canvasContainerSize.height, 1)
            let sx = exportSize.width / baseW
            let sy = exportSize.height / baseH
            return strokes.map { stroke in
                var s = stroke
                s.points = stroke.points.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
                s.lineWidth = stroke.lineWidth * ((sx + sy) / 2)
                return s
            }
        }
    }
}

private struct CanvasExportView: View {
    let workingCGImage: CGImage?
    let strokes: [Stroke]
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            if let workingCGImage {
                Image(decorative: workingCGImage, scale: 1)
                    .resizable()
                    .frame(width: size.width, height: size.height)
            }

            Canvas { context, _ in
                for stroke in strokes {
                    var path = Path()
                    guard let first = stroke.points.first else { continue }
                    let isDot = stroke.points.count == 1
                    if isDot {
                        let radius = stroke.lineWidth / 2
                        let rect = CGRect(x: first.x - radius, y: first.y - radius, width: stroke.lineWidth, height: stroke.lineWidth)
                        path.addEllipse(in: rect)
                    } else {
                        path.move(to: first)
                        for point in stroke.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }

                    if stroke.isEraser {
                        var eraserContext = context
                        eraserContext.blendMode = .destinationOut
                        if isDot {
                            eraserContext.fill(path, with: .color(.black))
                        } else {
                            eraserContext.stroke(
                                path,
                                with: .color(.black),
                                style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                    } else {
                        if isDot {
                            context.fill(path, with: .color(stroke.color))
                        } else {
                            context.stroke(
                                path,
                                with: .color(stroke.color),
                                style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct ScrollWheelZoomModifier: ViewModifier {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat

    func body(content: Content) -> some View {
        #if os(macOS)
        content.overlay(
            ScrollWheelZoomView(scale: $scale, lastScale: $lastScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        )
        #else
        content
        #endif
    }
}

#if os(macOS)
import AppKit

private struct ScrollWheelZoomView: NSViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelMonitorView()
        view.onScroll = { deltaY in
            let factor = 1.0 + (deltaY * 0.01)
            let newScale = min(max(scale * factor, 1.0), 5.0)
            DispatchQueue.main.async {
                scale = newScale
                lastScale = newScale
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ScrollWheelMonitorView {
            view.onScroll = { deltaY in
                let factor = 1.0 + (deltaY * 0.01)
                let newScale = min(max(scale * factor, 1.0), 5.0)
                DispatchQueue.main.async {
                    scale = newScale
                    lastScale = newScale
                }
            }
        }
    }
}

private final class ScrollWheelMonitorView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.window == event.window else { return event }
            // Only zoom when pointer is over this view's area.
            let location = self.convert(event.locationInWindow, from: nil)
            if self.bounds.contains(location) {
                self.onScroll?(event.scrollingDeltaY)
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
#endif

private struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    PaintingScreen()
}
