import SwiftUI
import PDFKit

/// Full-page preview of the document with the selected style, shown in a
/// separate sheet before exporting to PDF. Renders the same PDF the export
/// would produce, so pagination and margins match exactly.
struct DocumentPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let style: DocStyle
    let markdown: String

    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(style.name)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.faint)
                .padding(.leading, 10)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Group {
                if let document {
                    PDFPreview(document: document)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.sidebar)
        }
        .frame(width: 760, height: 860)
        .background(Theme.canvas)
        .task { await render() }
    }

    @MainActor
    private func render() async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("markport-preview-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        do {
            try await WebRenderer().exportPDF(markdown: markdown, style: style, to: tempURL)
            let data = try Data(contentsOf: tempURL)
            guard let loaded = PDFDocument(data: data) else {
                errorMessage = "Could not load the preview."
                return
            }
            document = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Renders a PDFDocument with pages visually separated by gaps, matching
/// how the exported file will paginate and margin its content.
private struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        view.backgroundColor = .underPageBackgroundColor
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }
}
