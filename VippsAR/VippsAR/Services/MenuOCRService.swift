import Vision
import UIKit
import CoreImage

/// Processes camera frames using the Vision text-recognition pipeline.
///
/// For each frame it:
///   1. Runs `VNRecognizeTextRequest` at the `.fast` recognition level (suitable for live video).
///   2. Pairs adjacent text observations that match a label+price pattern.
///   3. Returns `[DetectedCandidate]` with normalised bounding rects (0–1 space).
///
/// The actor isolation guarantees that Vision requests never race across frames.
actor MenuOCRService {

    // MARK: - Public

    /// Analyse a single camera frame and return price-line candidates.
    /// Call from a background task; safe to drop frames if the previous call is still running.
    func detect(in pixelBuffer: CVPixelBuffer) async -> [DetectedCandidate] {
        guard let cgImage = cgImage(from: pixelBuffer) else { return [] }

        do {
            let lines = try await recognizeText(in: cgImage)
            return priceCandidates(from: lines)
        } catch {
            return []
        }
    }

    // MARK: - OCR

    private func recognizeText(in image: CGImage) async throws -> [TextLine] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, err in
                if let err { continuation.resume(throwing: err); return }

                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { obs -> TextLine? in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return TextLine(
                        text: top.string,
                        confidence: top.confidence,
                        boundingBox: obs.boundingBox  // normalised, origin bottom-left
                    )
                }
                continuation.resume(returning: lines)
            }

            // Fast level is accurate enough for clean printed receipts and menus
            request.recognitionLevel       = .fast
            request.recognitionLanguages   = ["nb-NO", "da-DK", "en-US"]
            request.usesLanguageCorrection = false   // speed over correction in live mode

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do    { try handler.perform([request]) }
            catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Pairing logic

    /// Groups text lines into label+price pairs.
    ///
    /// Strategy: scan each line for a price pattern. If found, look for the
    /// nearest line on the same horizontal band that contains a label (non-numeric text).
    private func priceCandidates(from lines: [TextLine]) -> [DetectedCandidate] {
        var candidates: [DetectedCandidate] = []

        for line in lines {
            guard let price = extractPrice(from: line.text) else { continue }

            // Find a label on roughly the same vertical band (within 5% of the page height)
            let labelLine = lines.first { other in
                other.text != line.text &&
                abs(other.boundingBox.midY - line.boundingBox.midY) < 0.05 &&
                extractPrice(from: other.text) == nil &&
                other.text.count > 1
            }

            let label = labelLine?.label ?? line.labelPart ?? "Item"

            // Merge bounding boxes so the overlay covers both label and price
            let rect: CGRect
            if let lb = labelLine?.boundingBox {
                rect = line.boundingBox.union(lb).flippedY()
            } else {
                rect = line.boundingBox.flippedY()
            }

            candidates.append(DetectedCandidate(
                label: label,
                price: price,
                normalizedRect: rect,
                confidence: line.confidence
            ))
        }

        // Deduplicate by proximity (same item re-detected across frames)
        return deduplicated(candidates)
    }

    // MARK: - Price extraction

    private let priceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(\d{1,4})[,.](\d{2})"#
    )

    private func extractPrice(from text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "NOK", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "DKK", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "kr",  with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        guard let regex = priceRegex,
              let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
              let range = Range(match.range, in: cleaned) else { return nil }

        let raw = String(cleaned[range]).replacingOccurrences(of: ",", with: ".")
        return Decimal(string: raw)
    }

    // MARK: - Deduplication

    private func deduplicated(_ candidates: [DetectedCandidate]) -> [DetectedCandidate] {
        var result: [DetectedCandidate] = []
        for candidate in candidates {
            let isDuplicate = result.contains { existing in
                abs(existing.normalizedRect.midY - candidate.normalizedRect.midY) < 0.04 &&
                existing.price == candidate.price
            }
            if !isDuplicate { result.append(candidate) }
        }
        return result
    }

    // MARK: - CVPixelBuffer → CGImage

    private func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Supporting types

    private struct TextLine {
        let text: String
        let confidence: Float
        let boundingBox: CGRect      // Vision normalised coords (origin bottom-left)

        /// Strips trailing price portion to get a clean label.
        var label: String {
            text.components(separatedBy: CharacterSet.decimalDigits)
                .first?
                .trimmingCharacters(in: .init(charactersIn: " .,:-"))
                ?? text
        }

        /// Returns a label if the line contains both a name and a price on the same line.
        var labelPart: String? {
            let parts = text.components(separatedBy: "  ").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            return parts.first { !$0.isEmpty && !$0.allSatisfy(\.isNumber) }
        }
    }
}

// MARK: - CGRect helpers

private extension CGRect {
    /// Vision returns rects with origin at bottom-left; UIKit uses top-left.
    func flippedY() -> CGRect {
        CGRect(x: minX, y: 1 - maxY, width: width, height: height)
    }
}
