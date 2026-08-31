import AppKit
import SwiftUI

/// Font picker limited to families actually installed
/// on the system: what you pick here will exist at export time.
struct FontPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (String) -> Void

    @State private var query = ""
    @State private var selection: String?
    private let families = SystemFonts.families

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return families }
        return families.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                TextField("Search installed fonts", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                Text("\(filtered.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered, id: \.self) { family in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(family)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("Aa Bb Cc — 0123")
                                .font(Font(NSFont(name: family, size: 19)
                                    ?? NSFont.systemFont(ofSize: 19)))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selection == family ? Color.accentColor.opacity(0.15) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = family }
                        .onTapGesture(count: 2) { pick(family) }
                    }
                }
            }

            Divider()
            HStack {
                Text("Will be inserted as a `font-family` declaration in the CSS.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle())
                Button("Insert") { if let selection { pick(selection) } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selection == nil)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 520)
        .background(Theme.canvas)
    }

    private func pick(_ family: String) {
        onPick(family)
        dismiss()
    }
}
