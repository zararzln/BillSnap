import SwiftUI

/// Transparent overlay that sits on top of `CameraPreviewView`.
/// Renders a tappable bounding-box chip for every detected price line.
///
/// Coordinate mapping:
///   Vision returns normalised rects in UIKit space (origin top-left, Y downward).
///   We multiply by the view's actual size to get screen points.
struct AROverlayView: View {
    @Binding var candidates: [DetectedCandidate]
    let confirmedItems: [BillLineItem]
    let selectedDiner: Diner?
    let onTapCandidate: (DetectedCandidate) -> Void
    let onTapConfirmed: (UUID) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // 1 — Confirmed items: show as coloured chips with diner dots
                ForEach(confirmedItems) { item in
                    confirmedChip(item: item, in: geo.size)
                }

                // 2 — Unconfirmed candidates: show as pulsing "tap to add" chips
                ForEach(candidates) { candidate in
                    candidateChip(candidate: candidate, in: geo.size)
                }
            }
        }
    }

    // MARK: - Confirmed chip

    private func confirmedChip(item: BillLineItem, in size: CGSize) -> some View {
        let rect = item.normalizedRect.scaled(to: size)

        return VStack(alignment: .leading, spacing: 3) {
            Text(item.label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 2) {
                ForEach(Array(item.assignedDinerIDs), id: \.self) { dinerID in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.white.opacity(0.9))
                }
                if item.assignedDinerIDs.isEmpty {
                    Image(systemName: "questionmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(item.assignedDinerIDs.isEmpty ? Color.orange : Color.green)
                .opacity(0.88)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
        }
        .position(x: rect.midX, y: rect.minY - 18)
        .onTapGesture { onTapConfirmed(item.id) }
    }

    // MARK: - Candidate chip

    private func candidateChip(candidate: DetectedCandidate, in size: CGSize) -> some View {
        let rect = candidate.normalizedRect.scaled(to: size)

        return ZStack {
            // Bounding box outline
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)

            // Tap chip above the box
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                Text("\(candidate.label) · \(candidate.price.currencyString)")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
            }
            .offset(y: -(rect.height / 2) - 22)
            .onTapGesture { onTapCandidate(candidate) }
        }
        .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Helpers

private extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        CGRect(
            x: minX * size.width,
            y: minY * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }
}

private extension Decimal {
    var currencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "NOK"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}
