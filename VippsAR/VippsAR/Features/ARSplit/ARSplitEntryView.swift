import SwiftUI

/// Top-level entry point for a split session.
/// Manages the phase-step shell and delegates each step to its dedicated view.
struct ARSplitEntryView: View {
    @Environment(AppContainer.self) private var container
    @State private var session: ARSplitSession?

    var body: some View {
        Group {
            if let session {
                SplitSessionView(session: session) {
                    withAnimation { self.session = nil }
                }
            } else {
                startScreen
            }
        }
        .animation(.easeInOut, value: session == nil)
    }

    // MARK: - Start screen

    private var startScreen: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse)

                    Text("BillSnap")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Point at a bill. Tap the items.\nVipps handles the rest.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            session = ARSplitSession()
                        }
                    } label: {
                        Label("Start new split", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)

                    Text("Powered by Vision · \(VippsDeepLinkService.appNameForLocale())")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Session view (phase shell)

struct SplitSessionView: View {
    @Bindable var session: ARSplitSession
    let onDismiss: () -> Void
    @Environment(AppContainer.self) private var container

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .addDiners:
                    AddDinersView(session: session)
                case .scanBill:
                    ScanBillView(session: session)
                case .assignItems:
                    AssignItemsView(session: session)
                case .payment:
                    PaymentView(session: session, onDone: onDismiss)
                }
            }
            .navigationTitle(session.phase.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PhaseIndicator(current: session.phase)
                }
            }
        }
    }
}

// MARK: - Phase indicator pills

struct PhaseIndicator: View {
    let current: ARSplitSession.Phase

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ARSplitSession.Phase.allCases, id: \.self) { phase in
                Capsule()
                    .fill(phase == current ? Color.blue : Color(.systemGray4))
                    .frame(width: phase == current ? 16 : 6, height: 6)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
    }
}
