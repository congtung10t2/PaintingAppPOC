//
//  Untitled.swift
//  TestLocalAI
//
//  Created by congtungit on 18/11/26.
//

import SwiftUI
import ImagePlayground

struct ColoringTransformer: View {
    @State private var inputImage: CGImage? 
    @State private var outputImage: CGImage?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Coloring Page to AI Art")
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
                                    if isGenerating {
                                        ProgressView()
                                    } else {
                                        Text("Tap Transform")
                                            .font(.caption)
                                    }
                                }
                            )
                    }
                }
            }

            Button(action: {
                Task {
                    await transformColoringPage()
                }
            }) {
                Text(isGenerating ? "Generating..." : "Transform with AI")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isGenerating || inputImage == nil)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            Spacer()
        }
        .padding()
    }

    private func transformColoringPage() async {
        guard let inputImage else { return }
        
        isGenerating = true
        errorMessage = nil

        do {
            // Check if Image Playground / creation is supported on device
            if #available(iOS 18.2, *) {
                // Initialize the Image Creator
                let creator = try await ImageCreator()
                
                // Set up concept or description matching your target style (e.g., vibrant 3D animation, bright colors)
                let prompt = "A vibrant, glossy 3D cartoon style character, highly detailed shading, bright yellow and warm tones, clean studio lighting"
                
                // Request generation using Image Playground concepts/styles
                // Note: You can pass source concept hints or guide images depending on precise API iteration
              for try await image in creator.images(for: [.image(inputImage)], style: .animation, limit: 1) {
                    // Extract CGImage and convert to UIImage
                        let finalUIImage = image.cgImage
                        await MainActor.run {
                            self.outputImage = finalUIImage
                        }
                    }
            } else {
                await MainActor.run {
                    self.errorMessage = "Image Playground requires a compatible device running iOS 18.2+"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Generation failed: \(error.localizedDescription)"
            }
        }

        isGenerating = false
    }
}
