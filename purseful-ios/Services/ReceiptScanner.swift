import Foundation
import Vision
import UIKit

actor ReceiptScanner {
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ReceiptScannerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = Self.readingOrderText(from: observations)
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["pl-PL", "en-US"]
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.012

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func readingOrderText(from observations: [VNRecognizedTextObservation]) -> String {
        let sorted = observations.sorted { lhs, rhs in
            let left = lhs.boundingBox
            let right = rhs.boundingBox
            if abs(left.midY - right.midY) > 0.015 {
                return left.midY > right.midY
            }
            return left.minX < right.minX
        }

        return sorted
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

enum ReceiptScannerError: Error {
    case invalidImage
}
