import SwiftUI

struct AddDinersView: View {
    @Bindable var session: ARSplitSession
    @State private var name = ""
    @State private var phone = ""
    @State private var showingAddSheet = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Diner list
            List {
                if session.diners.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(session.diners) { diner in
                        DinerListRow(diner: diner)
                    }
                    .onDelete { offsets in
                        offsets.forEach { session.removeDiner(id: session.diners[$0].id) }
                    }
                }
            }
            .listStyle(.insetGrouped)

            Divider()

            // Inline add row
            HStack(spacing: 12) {
                TextField("Add name...", text: $name)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { addDiner() }

                Button(action: addDiner) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(name.isEmpty ? .tertiary : .blue)
                }
                .disabled(name.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)

            // CTA
            Button {
                session.advancePhase()
            } label: {
                Label("Scan the bill", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(session.diners.count >= 2 ? Color.blue : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(session.diners.count < 2)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 12)
        }
        .onAppear { nameFocused = true }
    }

    // MARK: - Actions

    private func addDiner() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        session.addDiner(name: name, phone: phone)
        name = ""
        phone = ""
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Add at least 2 people")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Row

struct DinerListRow: View {
    let diner: Diner

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(diner.color.color.opacity(0.18))
                    .frame(width: 40, height: 40)
                Text(diner.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(diner.color.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(diner.name)
                    .font(.body)
                if !diner.phone.isEmpty {
                    Text(diner.phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
