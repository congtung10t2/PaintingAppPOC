//
//  Untitled.swift
//  TestLocalAI
//
//  Created by congtungit on 18/11/26.
//
 
import SwiftUI
import ImagePlayground
 
struct ColoringTransformer: View {
    let inputImage: CGImage?
    @State private var outputImage: CGImage?
    @State private var errorMessage: String?
    @State private var isShowingImagePlayground = false
    /// Dismisses this popup without applying a result, so the user can pick
    /// another picture or try a different transform.
    @Environment(\.dismiss) private var dismiss
 
    /// Called when the user chooses to keep the original (untransformed) image.
    /// When `nil` (e.g. the gallery flow), the "Use Original" button is hidden.
    var onOriginal: ((CGImage) -> Void)?
 
    /// Called when the user accepts the AI-transformed output (the "OK" button).
    var onComplete: ((CGImage) -> Void)?
 
    init(inputImage: CGImage? = nil,
         onOriginal: ((CGImage) -> Void)? = nil,
         onComplete: ((CGImage) -> Void)? = nil) {
        self.inputImage = inputImage
        self.onOriginal = onOriginal
        self.onComplete = onComplete
    }
 
    var body: some View {
        VStack(spacing: 20) {
            // X button to cancel/dismiss this popup without applying a result.
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Cancel transform button")
            }

            Text("Transform to Painting Art")
                .font(.headline)
 
            HStack(spacing: 15) {
                // Input Line Art Preview
                if let inputImage {
                    VStack {
                        Text("Original")
                            .font(.caption)
                       Image(inputImage, scale: 1.0, label: Text("input"))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .border(Color.gray, width: 1)
                    }
                }
 
                // Output AI Colored Image Preview
                VStack {
                    Text("Result")
                        .font(.caption)
                    if let outputImage {
                       Image(outputImage, scale: 1.0, label: Text("output"))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .border(Color.blue, width: 1)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 180, height: 180)
                            .overlay(
                                Group {
                                    Text("Tap Transform")
                                        .font(.caption)
                                }
                            )
                    }
                }
            }
 
            Button(action: {
                isShowingImagePlayground = true
            }) {
                Text("Transform with AI")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            // Show any error that occurred during the last transform attempt.
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            }
            .disabled(inputImage == nil)
 
            // OK button — appears once a transform result is ready.
            Button {
                if let outputImage {
                    onComplete?(outputImage)
                }
            } label: {
                Text("OK")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(outputImage == nil)
            .accessibilityIdentifier("OK button")
 
            // Offer the untransformed original as an alternative. Only shown when
            // the caller provides `onOriginal` (e.g. the device/file picker path).
            if onOriginal != nil {
                Button {
                    if let inputImage {
                        onOriginal?(inputImage)
                    }
                } label: {
                    Text("Use Original")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(inputImage == nil)
                .accessibilityIdentifier("Use Original button")
            }
 
            Spacer()
        }
        .padding()
        .imagePlaygroundSheet(
            isPresented: $isShowingImagePlayground,
            concept: "Black and white and use thick draw remove unnescessary detail so we can make color for it",
            sourceImage: inputImage != nil ? Image(inputImage!, scale: 1.0, label: Text("input")) : nil,
            onCompletion: { url in
                if let cg = cgImage(from: url) {
                    outputImage = cg
                }
            }
        )
        .imagePlaygroundGenerationStyle(.illustration)
    }
 
    private func cgImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #elseif canImport(AppKit)
        return NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
}
