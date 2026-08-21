import AppKit
import WebKit

enum RenderError: LocalizedError {
    case load(String)
    case pdf(String)

    var errorDescription: String? {
        switch self {
        case .load(let m): return "No se pudo componer el documento: \(m)"
        case .pdf(let m): return "No se pudo generar el PDF: \(m)"
        }
    }
}

/// Recibe el callback de NSPrintOperation.runModal(for:delegate:didRun:contextInfo:).
private final class PrintCompletion: NSObject {
    var handler: ((Bool) -> Void)?

    @objc func printOperationDidRun(_ operation: NSPrintOperation,
                                    success: Bool,
                                    contextInfo: UnsafeMutableRawPointer?) {
        handler?(success)
        handler = nil
    }
}

/// Motor de composición: carga el HTML en un WKWebView fuera de pantalla y
/// produce PDF paginado (via NSPrintOperation, que respeta @page y saltos)
/// o miniaturas para la barra lateral.
@MainActor
final class WebRenderer: NSObject, WKNavigationDelegate {

    // Se crean al primer uso: instanciar un NSWindow durante el arranque
    // interfiere con el montaje de la escena de SwiftUI.
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792),
                             configuration: configuration)
        view.navigationDelegate = self
        return view
    }()

    private lazy var window: NSWindow = {
        let win = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 612, height: 792),
                           styleMask: [.borderless],
                           backing: .buffered,
                           defer: true)
        win.isReleasedWhenClosed = false
        win.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        win.contentView?.addSubview(webView)
        win.orderBack(nil)
        return win
    }()

    private var pending: CheckedContinuation<Void, Error>?
    private let printCompletion = PrintCompletion()

    private func resize(_ size: NSSize) {
        window.setContentSize(size)
        window.contentView?.frame = NSRect(origin: .zero, size: size)
        webView.frame = NSRect(origin: .zero, size: size)
    }

    private func load(fileURL: URL, readAccess: URL, viewport: NSSize) async throws {
        resize(viewport)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pending = continuation
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccess)
        }
        // Espera a que las fuentes (@font-face o del sistema) estén listas.
        _ = try? await webView.evaluateJavaScript("document.fonts.ready.then(() => 1)")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pending?.resume(); pending = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pending?.resume(throwing: RenderError.load(error.localizedDescription)); pending = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pending?.resume(throwing: RenderError.load(error.localizedDescription)); pending = nil
    }

    // MARK: - PDF

    func exportPDF(markdown: String, style: DocStyle, to destination: URL) async throws {
        let page = style.page
        let source = try Renderer.writeRenderFile(markdown: markdown, style: style,
                                                  filename: ".markport-export.html")
        defer { try? FileManager.default.removeItem(at: source) }

        try await load(fileURL: source, readAccess: style.folder, viewport: page.contentSize)

        let info = page.printInfo(savingTo: destination)
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        try? FileManager.default.removeItem(at: destination)

        // `run()` bloquea el run loop y WebKit nunca entrega el número de
        // páginas: hay que usar la variante modal, que sí lo cede.
        let success: Bool = await withCheckedContinuation { continuation in
            printCompletion.handler = { continuation.resume(returning: $0) }
            operation.runModal(for: window,
                               delegate: printCompletion,
                               didRun: #selector(PrintCompletion.printOperationDidRun(_:success:contextInfo:)),
                               contextInfo: nil)
        }

        guard success, FileManager.default.fileExists(atPath: destination.path) else {
            throw RenderError.pdf("la impresión no produjo ningún archivo")
        }
    }

    // MARK: - Miniatura

    func snapshot(markdown: String, style: DocStyle, width: CGFloat) async throws -> NSImage {
        let page = style.page
        let source = try Renderer.writeRenderFile(markdown: markdown, style: style,
                                                  filename: ".markport-preview.html",
                                                  cssFilename: Renderer.draftCSSName,
                                                  extraHead: Renderer.previewHead(page: page))
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: style.folder.appendingPathComponent(Renderer.draftCSSName))
        }

        try await load(fileURL: source, readAccess: style.folder, viewport: page.paperSize)

        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(origin: .zero, size: page.paperSize)
        configuration.snapshotWidth = NSNumber(value: Double(width))
        configuration.afterScreenUpdates = true
        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: RenderError.load(error?.localizedDescription ?? "snapshot"))
                }
            }
        }
    }
}
