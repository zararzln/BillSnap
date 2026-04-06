import SwiftUI

/// Phase 3: interactive assignment of each bill item to one or more diners.
/// Selecting a diner at the top filters the item list to show their current share.
struct AssignItemsView: View {
    @Bindable var session: ARSplitSession
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: 0) {
            // Diner selector
            dinerSelector
                .padding(.vertical, 12)

            Divider()

            // Item list
            List {
                Section {
                    ForEach($session.lineItems) { $item in
                        ItemAssignRow(
                            item: $item,
                            diners: session.diners,
                            onToggle: { dinerID in
                                session.toggleAssignment(itemID: item.id, dinerID: dinerID)
                                container.haptics.light()
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text("Bill items")
                        Spacer()
                        Text("Total: \(session.totalBill.currencyString)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Summary strip
            summaryStrip

            // CTA
            Button {
                session.advancePhase()
            } label: {
                Label("Review payments", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(session.allItemsAssigned ? Color.blue : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!session.allItemsAssigned)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
    }

    // MARK: - Diner selector

    private var dinerSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(session.diners) { diner in
                    let isSelected = session.selectedDinerID == diner.id
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            session.selectedDinerID = isSelected ? nil : diner.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(diner.color.color.opacity(isSelected ? 1 : 0.18))
                                    .frame(width: 28, height: 28)
                                Text(diner.initials)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : diner.color.color)
                            }
                            Text(diner.name)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .primary : .secondary)

                            Text(session.paymentBreakdown
                                .first { $0.diner.id == diner.id }?
                                .amount.currencyString ?? "–")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(isSelected ? .primary : .tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isSelected ? diner.color.color.opacity(0.12) : Color(.systemGray6))
                                .strokeBorder(isSelected ? diner.color.color : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let unassigned = session.lineItems.filter { $0.assignedDinerIDs.isEmpty }.count
        return Group {
            if unassigned > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(unassigned) item\(unassigned == 1 ? "" : "s") not yet assigned")
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.08))
            }
        }
    }
}

// MARK: - Item assign row

struct ItemAssignRow: View {
    @Binding var item: BillLineItem
    let diners: [Diner]
    let onToggle: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.label)
                    .font(.body)
                Spacer()
                Text(item.price.currencyString)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Diner toggle dots
            HStack(spacing: 8) {
                ForEach(diners) { diner in
                    let isOn = item.assignedDinerIDs.contains(diner.id)
                    Button {
                        onToggle(diner.id)
                    } label: {
                        HStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isOn ? diner.color.color : Color(.systemGray5))
                                    .frame(width: 22, height: 22)
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(diner.name.components(separatedBy: " ").first ?? diner.name)
                                .font(.caption2)
                                .foregroundStyle(isOn ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.2), value: isOn)
                }

                if item.isShared {
                    Spacer()
                    Text("÷ \(item.assignedDinerIDs.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
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
