import SwiftUI
import Combine

/// Phase 2: live camera feed with AR overlay.
/// The user points the camera at the bill; detected price lines float as tappable chips.
/// Tapping a chip promotes it to a confirmed `BillLineItem`.
struct ScanBillView: View {
    @Bindable var session: ARSplitSession
    @Environment(AppContainer.self) private var container

    @StateObject private var camera = CameraFeedController()
    @State private var isProcessingFrame = false
    @State private var frameSubscription: AnyCancellable?

    var body: some View {
        ZStack {
            // Layer 0: live camera feed
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Layer 1: AR bounding-box overlays
            AROverlayView(
                candidates: $session.detectedCandidates,
                confirmedItems: session.lineItems,
                selectedDiner: nil,
                onTapCandidate: { candidate in
                    withAnimation(.spring(duration: 0.25)) {
                        session.confirmCandidate(candidate)
                    }
                    container.haptics.medium()
                },
                onTapConfirmed: { _ in }
            )
            .ignoresSafeArea()

            // Layer 2: HUD
            VStack {
                scanHUD
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            camera.requestPermissionAndStart()
            startProcessingFrames()
        }
        .onDisappear {
            camera.stop()
            frameSubscription?.cancel()
        }
    }

    // MARK: - HUD

    private var scanHUD: some View {
        HStack(spacing: 8) {
            Image(systemName: "viewfinder")
                .symbolEffect(.pulse, isActive: session.isScanning)
            Text(session.lineItems.isEmpty
                 ? "Point at the bill — tap items to add"
                 : "\(session.lineItems.count) item\(session.lineItems.count == 1 ? "" : "s") added")
            .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 12)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Item count chips
            if !session.lineItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.lineItems) { item in
                            ConfirmedItemChip(item: item) {
                                withAnimation { session.removeLineItem(id: item.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            HStack(spacing: 12) {
                // Manual entry fallback
                Button {
                    // Shows manual entry sheet (handled in parent for simplicity)
                } label: {
                    Label("Add manually", systemImage: "keyboard")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button {
                    session.advancePhase()
                } label: {
                    Label("Assign items", systemImage: "hand.tap.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(session.lineItems.isEmpty ? Color(.systemGray4) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(session.lineItems.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Frame processing

    private func startProcessingFrames() {
        frameSubscription = camera.$latestFrame
            .compactMap { $0 }
            .sink { [weak session] buffer in
                guard let session, !self.isProcessingFrame else { return }
                self.isProcessingFrame = true

                Task {
                    let candidates = await self.container.ocrService.detect(in: buffer)
                    await MainActor.run {
                        // Merge new candidates without replacing confirmed items
                        let confirmedIDs = Set(session.lineItems.map(\.id))
                        session.detectedCandidates = candidates.filter { !confirmedIDs.contains($0.id) }
                        self.isProcessingFrame = false
                    }
                }
            }
    }
}

// MARK: - Chip for confirmed items in scroll row

private struct ConfirmedItemChip: View {
    let item: BillLineItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(item.label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text(item.price.currencyString)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

private extension Decimal {
    var currencyString: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "NOK"
        f.maximumFractionDigits = 2
        return f.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}
