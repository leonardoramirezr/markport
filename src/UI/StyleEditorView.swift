import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct StyleEditorView: View {
    @EnvironmentObject private var store: StyleStore
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var previews: PreviewCache
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable { case css = "CSS", html = "HTML" }

    @State private var draft: DocStyle
    @State private var tab: Tab = .css
    @State private var showingFonts = false
    @State private var missing: [String] = []
    @StateObject private var cssController = EditorController()
    @StateObject private var htmlController = EditorController()

    private let isNew: Bool

    init(style: DocStyle) {
        _draft = State(initialValue: style)
        isNew = !FileManager.default.fileExists(atPath: style.folder.appendingPathComponent("meta.json").path)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                editorColumn.frame(minWidth: 420)
                Divider()
                previewColumn.frame(width: 360)
            }
        }
        .frame(width: 1000, height: 660)
        .background(Theme.canvas)
        .sheet(isPresented: $showingFonts) {
            FontPickerView { family in
                tab = .css
                cssController.insert("\n    " + SystemFonts.declaration(for: family) + "\n")
                syncFromEditors()
            }
        }
        .onAppear { missing = SystemFonts.missingFamilies(in: draft.css) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            TextField("Style name", text: $draft.name)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: 280, alignment: .leading)

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            Button("Cancel") {
                Renderer.removeTemporaryFiles(in: draft)
                if isNew { try? FileManager.default.removeItem(at: draft.folder) }
                dismiss()
            }
            .buttonStyle(QuietButtonStyle())

            Button("Save") {
                syncFromEditors()
                var clean = draft
                clean.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.name.isEmpty { clean.name = store.uniqueName(base: "Style") }
                let saved = store.save(clean)
                Renderer.removeTemporaryFiles(in: saved)
                previews.invalidate(saved)
                state.selectedStyleID = saved.id
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: Editors

    private var editorColumn: some View {
        VStack(spacing: 0) {
            ZStack {
                if tab == .css {
                    CodeTextView(initialText: draft.css,
                                 font: Theme.editorFont(),
                                 controller: cssController,
                                 padding: 14) { text in
                        draft.css = text
                        missing = SystemFonts.missingFamilies(in: text)
                    }
                } else {
                    CodeTextView(initialText: draft.html,
                                 font: Theme.editorFont(),
                                 controller: htmlController,
                                 padding: 14) { text in
                        draft.html = text
                    }
                }
            }
            Divider()
            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !missing.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("Not installed on the system: \(missing.joined(separator: ", ")). The PDF will use a substitute font.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                Button {
                    syncFromEditors()
                    showingFonts = true
                } label: {
                    Label("System font…", systemImage: "textformat")
                }
                .buttonStyle(QuietButtonStyle())

                Button("Upload file…") { importFile() }
                    .buttonStyle(QuietButtonStyle())

                Button("Add font…") { importFontFile() }
                    .buttonStyle(QuietButtonStyle())

                Spacer()

                Text("\(draft.page.label) · \(Int(draft.page.paperSize.width))×\(Int(draft.page.paperSize.height)) pt")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Preview

    private var previewColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    syncFromEditors()
                } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.faint)
                .help("Refresh preview")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            GeometryReader { geo in
                let page = draft.page
                let width = geo.size.width - 32
                let height = width * (page.paperSize.height / max(page.paperSize.width, 1))
                StylePreviewWeb(style: draft, markdown: sampleMarkdown, targetWidth: width)
                    .frame(width: width, height: min(height, geo.size.height - 28))
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .background(Theme.sidebar)
    }

    private var sampleMarkdown: String {
        let text = state.markdownController.text.isEmpty ? state.markdown : state.markdownController.text
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? DefaultAssets.sampleMarkdown : text
    }

    // MARK: Actions

    private func syncFromEditors() {
        if let css = cssController.textView?.string { draft.css = css }
        if let html = htmlController.textView?.string { draft.html = html }
        missing = SystemFonts.missingFamilies(in: draft.css)
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "css") ?? .plainText,
                                     .html, .plainText]
        panel.title = "Upload CSS or HTML"
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        if url.pathExtension.lowercased() == "css" {
            draft.css = text
            cssController.setText(text)
            tab = .css
            missing = SystemFonts.missingFamilies(in: text)
        } else {
            draft.html = text
            htmlController.setText(text)
            tab = .html
        }
    }

    private func importFontFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "woff2") ?? .data,
                                     UTType(filenameExtension: "woff") ?? .data,
                                     .font]
        panel.title = "Add font files to style"
        guard panel.runModal() == .OK else { return }
        var added: [String] = []
        for url in panel.urls {
            if let path = store.importResource(url, into: draft, subfolder: "fonts") { added.append(path) }
        }
        guard let first = added.first else { return }
        let family = URL(fileURLWithPath: first).deletingPathExtension().lastPathComponent
        let faces = added.map { path in
            """
            @font-face {
                font-family: "\(family)";
                src: url("\(path)") format("\(format(for: path))");
            }
            """
        }.joined(separator: "\n\n")
        tab = .css
        cssController.insert("\n" + faces + "\n")
        syncFromEditors()
    }

    private func format(for path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "woff2": return "woff2"
        case "woff": return "woff"
        case "otf": return "opentype"
        default: return "truetype"
        }
    }
}

/// Live preview: WKWebView loaded from the style's folder,
/// scaled so the paper width matches the panel.
struct StylePreviewWeb: NSViewRepresentable {
    let style: DocStyle
    let markdown: String
    let targetWidth: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsMagnification = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let page = style.page
        // A plain (non-print) WKWebView load treats the view's frame width
        // (in AppKit points) as a literal CSS pixel count, with no further
        // conversion -- unlike WebKit's print pipeline, which lays out CSS
        // pixels against the page's true physical size (96px = 1in = 72pt).
        // Zooming by paperSize.width alone therefore reflows text into a
        // column ~33% narrower than what actually prints, so it reads
        // larger relative to the page. Scale the zoom by 72/96 so the
        // effective CSS-pixel viewport matches the printed page's.
        let zoom = max(0.15, targetWidth / max(page.paperSize.width, 1) * (72.0 / 96.0))
        if abs(webView.pageZoom - zoom) > 0.001 { webView.pageZoom = zoom }

        let signature = "\(style.fingerprint)|\(markdown.hashValue)"
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature
        guard let url = try? Renderer.writeRenderFile(markdown: markdown,
                                                      style: style,
                                                      filename: ".markport-live.html",
                                                      cssFilename: Renderer.draftCSSName,
                                                      extraHead: Renderer.previewHead(page: page))
        else { return }
        webView.loadFileURL(url, allowingReadAccessTo: style.folder)
    }

    final class Coordinator { var signature = "" }
}
