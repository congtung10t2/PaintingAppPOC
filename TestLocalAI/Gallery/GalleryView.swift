//
//  GalleryView.swift
//  TestLocalAI
//
//  Created by congtungit on 15/11/26.
//

import SwiftUI

private let galleryGrayscaleDetector = ImageProcessor()

/// The full-screen gallery presented from the Paint screen.
///
/// The tab bar mirrors the main navigation's tab structure: "Drawings" shows
/// gallery line art and "Custom" shows user-provided pictures. Tapping a picture
/// pushes a **new** `ColoringTransformer` view (a separate navigation destination,
/// not this gallery) using that picture as its input image. When the user taps
/// OK in the transformer, the transformed result is forwarded via
/// `onTransformResult`.
struct GalleryView: View {
    /// Called when a transform result is produced by the `ColoringTransformer`
    /// (after the user taps OK). The result is the AI-transformed `CGImage`.
    let onTransformResult: (CGImage) -> Void

    /// Converts a selected picture into the line-art `CGImage` fed to the
    /// `ColoringTransformer` as its input (includes the black-and-white
    /// conversion for real `.image` pictures). Provided by `PaintingScreen`.
    let convert: (GalleryPicture) -> CGImage?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: GalleryTab = .snowMan

    private var currentPictures: [GalleryPicture] {
        switch selectedTab {
        case .snowMan:
            GalleryCatalog.snowManPictures
        case .pikachu:
            GalleryCatalog.pikachuPictures
        case .chibiGirl:
            GalleryCatalog.chibiGirlPictures
        case .chibiBoy:
            GalleryCatalog.chibiBoyPictures
        case .witch:
            GalleryCatalog.witchPictures
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented tab picker that mirrors the main navigation structure.
                Picker("Picture Gallery", selection: $selectedTab) {
                    ForEach(GalleryTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(currentPictures) { picture in
                            // Tapping a picture pushes a NEW ColoringTransformer
                            // (a separate navigation destination), not this gallery.
                            NavigationLink(value: picture) {
                                galleryThumbnail(for: picture)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Picture Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            // Navigate to a fresh ColoringTransformer for each selected picture.
            // If the converted picture is already black-and-white, skip the
            // "Transform with AI" view and forward it directly to the paint screen.
            .navigationDestination(for: GalleryPicture.self) { picture in
                if let cg = convert(picture), galleryGrayscaleDetector.isBlackAndWhite(cg) {
                    onTransformResult(cg)
                    dismiss()
                    return AnyView(Color.clear)
                }
                return AnyView(
                    ColoringTransformer(
                        inputImage: convert(picture),
                        onOriginal: { original in
                            onTransformResult(original)
                            dismiss()
                        },
                        onComplete: { result in
                            // OK tapped and a result was produced: forward it back to the
                            // Paint screen and return to the previous screen.
                            onTransformResult(result)
                            dismiss()
                        }
                    )
                )
            }
        }
    }

    // MARK: - Gallery UI

    @ViewBuilder
    private func galleryThumbnail(for picture: GalleryPicture) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))

                if let cg = GalleryCatalog.makeImage(for: picture, size: CGSize(width: 180, height: 180)) {
                    Image(decorative: cg, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(height: 100)
            .clipped()

            Text(picture.name)
                .font(.caption)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Tab types

    private enum GalleryTab: String, CaseIterable, Identifiable {
        case snowMan
        case pikachu
        case chibiGirl
        case chibiBoy
        case witch

        var id: String { rawValue }

        var title: String {
            switch self {
          
            case .snowMan: "Snow Man"
            case .pikachu: "Pikachu"
            case .chibiGirl: "Chibi Girl"
            case .chibiBoy: "Chibi Boy"
            case .witch: "Witch"
            }
        }

        var systemImage: String {
            switch self {
            case .snowMan: "person.fill"
            case .pikachu: "bolt.fill"
            case .chibiGirl: "person.fill"
            case .chibiBoy: "figure.standing"
            case .witch: "sparkles"
            }
        }
    }
}
