import Foundation
import Observation
import UIKit

/// Drives the entire AR bill-splitting session.
///
/// Flow:
///   1. User opens camera → `CameraFeedView` streams frames into `MenuOCRService`
///   2. OCR finds text bounding boxes → stored as `DetectedItem` candidates
///   3. User taps a candidate → promoted to a `BillLineItem`
///   4. User assigns each `BillLineItem` to one or more `Diner`s
///   5. `paymentBreakdown` computes each diner's share
///   6. `VippsDeepLinkService` opens the payment app per diner
@Observable
final class ARSplitSession {

    // MARK: - Diners
    var diners: [Diner] = []

    // MARK: - Detected items from OCR (raw candidates shown as AR overlays)
    var detectedCandidates: [DetectedCandidate] = []

    // MARK: - Confirmed bill line items
    var lineItems: [BillLineItem] = []

    // MARK: - UI state
    var phase: Phase = .addDiners
    var selectedDinerID: UUID?
    var isScanning: Bool = false
    var scanPulse: Bool = false

    // MARK: - Computed

    var selectedDiner: Diner? {
        diners.first { $0.id == selectedDinerID }
    }

    var totalBill: Decimal {
        lineItems.reduce(0) { $0 + $1.price }
    }

    var paymentBreakdown: [DinerPayment] {
        diners.map { diner in
            let share = lineItems
                .filter { $0.assignedDinerIDs.contains(diner.id) }
                .reduce(Decimal(0)) { sum, item in
                    let splitCount = Decimal(max(1, item.assignedDinerIDs.count))
                    return sum + (item.price / splitCount).rounded(scale: 2)
                }
            return DinerPayment(diner: diner, amount: share)
        }
    }

    var allItemsAssigned: Bool {
        !lineItems.isEmpty && lineItems.allSatisfy { !$0.assignedDinerIDs.isEmpty }
    }

    // MARK: - Mutations

    func addDiner(name: String, phone: String = "") {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        diners.append(Diner(name: name, phone: phone))
    }

    func removeDiner(id: UUID) {
        diners.removeAll { $0.id == id }
        // Unassign removed diner from all items
        for idx in lineItems.indices {
            lineItems[idx].assignedDinerIDs.remove(id)
        }
    }

    func confirmCandidate(_ candidate: DetectedCandidate) {
        guard !lineItems.contains(where: { $0.id == candidate.id }) else { return }
        let item = BillLineItem(
            id: candidate.id,
            label: candidate.label,
            price: candidate.price,
            normalizedRect: candidate.normalizedRect
        )
        lineItems.append(item)
        detectedCandidates.removeAll { $0.id == candidate.id }
    }

    func removeLineItem(id: UUID) {
        lineItems.removeAll { $0.id == id }
    }

    func toggleAssignment(itemID: UUID, dinerID: UUID) {
        guard let idx = lineItems.firstIndex(where: { $0.id == itemID }) else { return }
        if lineItems[idx].assignedDinerIDs.contains(dinerID) {
            lineItems[idx].assignedDinerIDs.remove(dinerID)
        } else {
            lineItems[idx].assignedDinerIDs.insert(dinerID)
        }
    }

    func assignToSelectedDiner(itemID: UUID) {
        guard let dinerID = selectedDinerID else { return }
        toggleAssignment(itemID: itemID, dinerID: dinerID)
    }

    func advancePhase() {
        switch phase {
        case .addDiners:   phase = .scanBill
        case .scanBill:    phase = .assignItems
        case .assignItems: phase = .payment
        case .payment:     break
        }
    }

    // MARK: - Types

    enum Phase: Int, CaseIterable {
        case addDiners   = 0
        case scanBill    = 1
        case assignItems = 2
        case payment     = 3

        var title: String {
            switch self {
            case .addDiners:   return "Who's eating?"
            case .scanBill:    return "Scan the bill"
            case .assignItems: return "Who had what?"
            case .payment:     return "Pay up"
            }
        }

        var icon: String {
            switch self {
            case .addDiners:   return "person.2"
            case .scanBill:    return "camera.viewfinder"
            case .assignItems: return "hand.tap"
            case .payment:     return "arrow.up.circle"
            }
        }
    }
}

// MARK: - Supporting value types

struct Diner: Identifiable {
    let id: UUID = UUID()
    var name: String
    var phone: String
    var color: DinerColor = DinerColor.allCases.randomElement() ?? .blue

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

struct BillLineItem: Identifiable {
    let id: UUID
    var label: String
    var price: Decimal
    var normalizedRect: CGRect          // 0–1 coordinate space from Vision
    var assignedDinerIDs: Set<UUID> = []

    var isShared: Bool { assignedDinerIDs.count > 1 }
}

struct DetectedCandidate: Identifiable {
    let id: UUID = UUID()
    let label: String
    let price: Decimal
    let normalizedRect: CGRect
    var confidence: Float
}

struct DinerPayment {
    let diner: Diner
    let amount: Decimal
}

enum DinerColor: String, CaseIterable {
    case blue, purple, pink, orange, teal, green, red

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .purple: return .purple
        case .pink:   return .pink
        case .orange: return .orange
        case .teal:   return .teal
        case .green:  return .green
        case .red:    return .red
        }
    }
}

// MARK: - Decimal helper
private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var mutable = self
        NSDecimalRound(&result, &mutable, scale, .plain)
        return result
    }
}
