import SwiftUI

struct GalleryView: View {
    let onSelect: (GalleryPicture) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: GalleryTab = .drawings

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 16)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Gallery Tab", selection: $selectedTab) {
                    ForEach(GalleryTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(currentPictures) { picture in
                            Button {
                                onSelect(picture)
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    if let cg = GalleryCatalog.makeImage(for: picture, size: CGSize(width: 180, height: 180)) {
                                        Image(decorative: cg, scale: 1)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                            .padding(8)
                                            .background(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }

                                    Text(picture.name)
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Picture Gallery")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var currentPictures: [GalleryPicture] {
        switch selectedTab {
        case .drawings:
            return GalleryCatalog.drawings
        case .realPics:
            return GalleryCatalog.customRealPictures
        }
    }
}

private enum GalleryTab: String, CaseIterable, Identifiable {
    case drawings
    case realPics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drawings: return "Drawings"
        case .realPics: return "Real Pics"
        }
    }
}
