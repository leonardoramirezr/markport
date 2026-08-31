import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedStyleID: String?
    @Published var editing: DocStyle?
    @Published var isExporting = false
    @Published var showingPreview = false
    @Published var message: Message?

    /// El Markdown vive en el NSTextView; aquí solo guardamos la última
    /// versión amortiguada para exportar y persistir.
    var markdown: String

    let markdownController = EditorController()
    private lazy var renderer = WebRenderer()
    private var saveWork: DispatchWorkItem?

    struct Message: Identifiable {
        let id = UUID()
        var text: String
        var fileURL: URL?
        var isError = false
    }

    static let draftURL = StyleStore.support.appendingPathComponent("draft.md")

    init() {
        markdown = (try? String(contentsOf: Self.draftURL, encoding: .utf8)) ?? DefaultAssets.welcomeMarkdown
    }

    func markdownChanged(_ value: String) {
        markdown = value
        saveWork?.cancel()
        let item = DispatchWorkItem {
            try? value.write(to: Self.draftURL, atomically: true, encoding: .utf8)
        }
        saveWork = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    func style(in store: StyleStore) -> DocStyle? {
        if let id = selectedStyleID, let match = store.styles.first(where: { $0.id == id }) { return match }
        return store.styles.first
    }

    func export(store: StyleStore) {
        guard let style = style(in: store) else { return }
        let text = markdownController.text.isEmpty ? markdown : markdownController.text
        markdown = text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = Message(text: "No hay Markdown que exportar.", isError: true)
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename(for: text)
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.title = "Exportar PDF"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        isExporting = true
        Task {
            do {
                try await renderer.exportPDF(markdown: text, style: style, to: destination)
                message = Message(text: "PDF exportado a \(destination.lastPathComponent)", fileURL: destination)
            } catch {
                message = Message(text: error.localizedDescription, isError: true)
            }
            isExporting = false
        }
    }

    private func suggestedFilename(for markdown: String) -> String {
        let title = Markdown.title(from: markdown)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let clean = title.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
            .trimmingCharacters(in: .whitespaces)
        return (clean.isEmpty ? "Documento" : clean) + ".pdf"
    }
}
