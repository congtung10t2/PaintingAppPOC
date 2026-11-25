//
//  LineArtGenerator.swift
//  PaintingAppPOC
//
//  Uses the on-device Apple Intelligence model (Foundation Models) to describe
//  how a picture reads as black-and-white line art for a coloring page. The app
//  then renders the colorable line-art image with Core Image from the plan.
//

import CoreImage
import FoundationModels
import SwiftUI

#if canImport(FoundationModels)

/// What the on-device model describes about a picture when turning it into a
/// coloring page. Foundation Models produces text, so the plan guides the
/// Core Image line-art render.
@Generable
struct LineArtPlan: Equatable {
    @Guide(description: "The main subject of the picture and the key shapes you would draw.")
    var subject: String
    @Guide(description: "How the outlines should read: for example 'thick outlines for coloring' or 'sketchy thin lines'.")
    var outlineStyle: String
    @Guide(description: "A short artist instruction, like 'draw only outlines and leave the background blank'.")
    var instructions: String
}

enum LineArtGeneratorError: Error, LocalizedError {
    case modelUnavailable
    case generationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "The AI transform isn't available on this device yet."
        case .generationFailed(let error):
            return "The AI transform failed: \(error.localizedDescription)"
        }
    }
}

/// Generates the black-and-white line-art image that a picture becomes when it
/// becomes a coloring page.
struct LineArtGenerator {
    private let imageProcessor = ImageProcessor()

    /// Asks the on-device model to describe the picture's line art and returns
    /// the colorable line-art image together with the model's plan.
    func generate(from inputImage: CGImage) async throws -> (lineArt: CGImage, plan: LineArtPlan) {
        guard case .available = SystemLanguageModel.default.availability else {
            throw LineArtGeneratorError.modelUnavailable
        }

        let session = LanguageModelSession(instructions: """
            You describe pictures as black and white stroke line art for coloring pages. \
            You describe the main subject, how bold the outlines should be, and \
            one short artist instruction. You never invent colors.
            """)

        let prompt = Prompt {
            "Transform this picture to black and white thick line art for a coloring page and remove unnescessary detailed."
            Attachment(inputImage)
        }

        let plan: LineArtPlan
        do {
            plan = try await session.respond(to: prompt, generating: LineArtPlan.self).content
        } catch {
            throw LineArtGeneratorError.generationFailed(error)
        }

        let lineArt = imageProcessor.lineArt(from: inputImage)
        return (lineArt ?? inputImage, plan)
    }
}

#endif
