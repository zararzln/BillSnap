import SwiftUI
import SwiftData

/// Phase 4: shows each diner's total and a "Pay with Vipps" button per person.
struct PaymentView: View {
    let session: ARSplitSession
    let onDone: () -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var paidIDs: Set<UUID> = []
    @State private var showPhoneEntry: UUID?
    @State private var phoneInput = ""

    private var breakdown: [DinerPayment] { session.paymentBreakdown }
    private var allPaid: Bool { paidIDs.count == breakdown.count }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Summary") {
                    LabeledContent("Total bill", value: session.totalBill.currencyString)
                    LabeledContent("People",     value: "\(session.diners.count)")
                }

                Section("Pay up") {
                    ForEach(breakdown, id: \.diner.id) { payment in
                        PaymentRow(
                            payment: payment,
                            isPaid: paidIDs.contains(payment.diner.id),
                            appName: container.vippsService.appName,
                            brandColor: container.vippsService.brandColor,
                            onPay: { handlePay(payment: payment) },
                            onPhoneNeeded: { showPhoneEntry = payment.diner.id }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)

            if allPaid {
                allPaidBanner
            } else {
                Button {
                    saveSessionAndDismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .padding(.top, 8)
            }
        }
        .alert("Phone number for \(dinerName(showPhoneEntry))", isPresented: .constant(showPhoneEntry != nil)) {
            TextField("Phone number", text: $phoneInput)
                .keyboardType(.phonePad)
            Button("Pay") {
                if let id = showPhoneEntry,
                   let idx = session.diners.firstIndex(where: { $0.id == id }) {
                    // Mutating through session is acceptable here — session is a class
                    session.diners[idx].phone = phoneInput
                    if let payment = breakdown.first(where: { $0.diner.id == id }) {
                        handlePay(payment: payment)
                    }
                }
                showPhoneEntry = nil
                phoneInput = ""
            }
            Button("Cancel", role: .cancel) {
                showPhoneEntry = nil
                phoneInput = ""
            }
        }
    }

    // MARK: - All paid

    private var allPaidBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
            Text("Everyone's settled up!")
                .font(.headline)
            Button("Start new split", action: {
                saveSessionAndDismiss()
            })
            .font(.subheadline)
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helpers

    private func handlePay(payment: DinerPayment) {
        let diner = payment.diner
        guard !diner.phone.isEmpty else {
            showPhoneEntry = diner.id
            return
        }

        if let url = container.vippsService.paymentURL(
            amount: payment.amount,
            recipient: diner.phone,
            message: "BillSnap"
        ), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { paidIDs.insert(diner.id) }
                container.haptics.success()
            }
        }
    }

    private func dinerName(_ id: UUID?) -> String {
        session.diners.first { $0.id == id }?.name ?? ""
    }

    private func saveSessionAndDismiss() {
        let record = BillSession(
            total: session.totalBill,
            currencyCode: Locale.current.currency?.identifier ?? "NOK",
            date: .now,
            dinerCount: session.diners.count
        )
        modelContext.insert(record)
        try? modelContext.save()
        onDone()
    }
}

// MARK: - Payment row

struct PaymentRow: View {
    let payment: DinerPayment
    let isPaid: Bool
    let appName: String
    let brandColor: Color
    let onPay: () -> Void
    let onPhoneNeeded: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(payment.diner.color.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(payment.diner.initials)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(payment.diner.color.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.diner.name)
                    .font(.body)
                Text(payment.amount.currencyString)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isPaid {
                Label("Paid", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                    .labelStyle(.iconOnly)
                    .font(.title2)
            } else {
                Button(action: onPay) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(appName)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(brandColor.opacity(0.12))
                    .foregroundStyle(brandColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .opacity(isPaid ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: isPaid)
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
