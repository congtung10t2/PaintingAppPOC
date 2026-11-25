//
//  Untitled.swift
//  PaintingAppPOC
//
//  Created by congtungit on 18/11/26.
//
 
import SwiftUI
 
struct ColoringTransformer: View {
    let inputImage: CGImage?
    @State private var outputImage: CGImage?
    @State private var errorMessage: String?
    /// True while the on-device model is describing the picture.
    @State private var isTransforming = false
    /// The model's plan for the coloring page, shown as a caption under the result.
    @State private var planText: String?
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

            Text("Coloring Page")
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
                                    Text("Tap Generate")
                                        .font(.caption)
                                }
                            )
                    }

                    if let planText {
                        Text(planText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
 
            Button(action: runTransform) {
                Text(isTransforming ? "Generating…" : "Generate Coloring Page")
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
            .disabled(inputImage == nil || isTransforming)
 
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
    }

    /// Starts the Foundation Models-based transform: the on-device model
    /// describes the picture as black-and-white line art, then Core Image
    /// renders the colorable page image.
    private func runTransform() {
        guard let inputImage else { return }
        Task {
            isTransforming = true
            defer { isTransforming = false }
            do {
                let result = try await LineArtGenerator().generate(from: inputImage)
                outputImage = result.lineArt
                planText = [result.plan.subject, result.plan.outlineStyle, result.plan.instructions]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            } catch {
                errorMessage = "AI transform unavailable on this device."
            }
        }
    }
}
