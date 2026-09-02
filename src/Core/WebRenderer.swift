import AppKit
import WebKit
import PDFKit

enum RenderError: LocalizedError {
    case load(String)
    case pdf(String)

    var errorDescription: String? {
        switch self {
        case .load(let m): return "Could not compose the document: \(m)"
        case .pdf(let m): return "Could not generate the PDF: \(m)"
        }
    }
}

/// Receives the callback from NSPrintOperation.runModal(for:delegate:didRun:contextInfo:).
private final class PrintCompletion: NSObject {
    var handler: ((Bool) -> Void)?

    @objc func printOperationDidRun(_ operation: NSPrintOperation,
                                    success: Bool,
                                    contextInfo: UnsafeMutableRawPointer?) {
        handler?(success)
        handler = nil
    }
}

/// Composition engine: loads the HTML into an off-screen WKWebView and
/// produces paginated PDF (via NSPrintOperation, which respects @page and
/// page breaks) or thumbnails for the sidebar.
@MainActor
final class WebRenderer: NSObject, WKNavigationDelegate {

    // Created on first use: instantiating an NSWindow during startup
    // interferes with SwiftUI's scene setup.
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
        // Off-screen coordinates alone aren't reliable: AppKit can constrain
        // a window whose frame doesn't intersect any real screen back onto
        // the main display (visible, cascaded) once it's ordered on screen.
        // Making it fully transparent keeps it invisible even then.
        win.alphaValue = 0
        win.ignoresMouseEvents = true
        win.hasShadow = false
        // While the app is fullscreen, a newly created window is placed on
        // the active (fullscreen) Space; since (-30000, -30000) doesn't
        // intersect that Space's screen bounds, AppKit falls back to a
        // visible cascaded position. `.transient` keeps it off Spaces/
        // Exposé bookkeeping; alpha 0 above keeps it invisible regardless.
        win.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        win.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        win.contentView?.addSubview(webView)
        win.orderBack(nil)
        isWindowLoaded = true
        return win
    }()

    deinit {
        MainActor.assumeIsolated {
            if isWindowLoaded {
                window.orderOut(nil)
                window.close()
            }
        }
    }

    /// Avoids instantiating `window` from `deinit` just to close it.
    private var isWindowLoaded = false

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
        // Wait for the fonts (@font-face or system) to be ready.
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

        // WebKit's print pipeline clips all drawing -- including backgrounds --
        // to the content box defined by `@page { margin }`, so the page margins
        // themselves are never painted. Detect the intended page color now,
        // while the document is loaded, and paint it in behind the PDF's own
        // content after printing so the exported margins match the on-screen background.
        let backgroundColor = await detectPageBackgroundColor()

        let info = page.printInfo(savingTo: destination)
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        try? FileManager.default.removeItem(at: destination)

        // `run()` blocks the run loop and WebKit never reports the page
        // count: we need the modal variant, which does yield it.
        let success: Bool = await withCheckedContinuation { continuation in
            printCompletion.handler = { continuation.resume(returning: $0) }
            operation.runModal(for: window,
                               delegate: printCompletion,
                               didRun: #selector(PrintCompletion.printOperationDidRun(_:success:contextInfo:)),
                               contextInfo: nil)
        }

        guard success, FileManager.default.fileExists(atPath: destination.path) else {
            throw RenderError.pdf("printing did not produce any file")
        }

        if let backgroundColor {
            try? Self.paintPageBackground(of: destination, color: backgroundColor)
        }
    }

    /// Reads the effective page background from the loaded document (`html`,
    /// falling back to `body`), so the PDF can be given the same color even
    /// though WebKit's print engine won't paint it into the page margins itself.
    private func detectPageBackgroundColor() async -> CGColor? {
        let js = """
        (function () {
            function isTransparent(c) { return !c || c === 'rgba(0, 0, 0, 0)' || c === 'transparent'; }
            var htmlBg = getComputedStyle(document.documentElement).backgroundColor;
            if (!isTransparent(htmlBg)) return htmlBg;
            var bodyBg = getComputedStyle(document.body).backgroundColor;
            if (!isTransparent(bodyBg)) return bodyBg;
            return null;
        })();
        """
        guard let css = try? await webView.evaluateJavaScript(js) as? String else { return nil }
        return Self.parseCSSColor(css)
    }

    /// Parses a computed-style color string (`rgb(r, g, b)` / `rgba(r, g, b, a)`).
    private static func parseCSSColor(_ css: String) -> CGColor? {
        let inner = css
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3,
              let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) else { return nil }
        if parts.count >= 4, let a = Double(parts[3]), a <= 0 { return nil }
        return NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1).cgColor
    }

    /// Fills every page of the PDF at `url` with `color` behind its existing
    /// (vector) content, so the page background reaches all the way to the
    /// physical edges instead of stopping at the printable content box.
    private static func paintPageBackground(of url: URL, color: CGColor) throws {
        guard let document = PDFDocument(url: url), let firstPage = document.page(at: 0) else {
            throw RenderError.pdf("could not reopen the generated PDF")
        }
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw RenderError.pdf("could not create a PDF writer")
        }
        var mediaBox = firstPage.bounds(for: .mediaBox)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw RenderError.pdf("could not create a PDF context")
        }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .mediaBox)
            context.beginPDFPage(nil)
            context.saveGState()
            context.setFillColor(color)
            context.fill(box)
            context.restoreGState()
            page.draw(with: .mediaBox, to: context)
            context.endPDFPage()
        }
        context.closePDF()
        try output.write(to: url, options: .atomic)
    }

    // MARK: - Thumbnail

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

        // A plain (non-print) WKWebView load treats the view's frame width
        // (in AppKit points) as a literal CSS pixel count, unlike WebKit's
        // print pipeline, which lays out CSS pixels against the page's true
        // physical size (96px = 1in = 72pt). Scale the viewport by 96/72 so
        // text reflows the same way it will when printed/exported.
        let cssSize = NSSize(width: page.paperSize.width * (96.0 / 72.0),
                             height: page.paperSize.height * (96.0 / 72.0))
        try await load(fileURL: source, readAccess: style.folder, viewport: cssSize)

        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(origin: .zero, size: cssSize)
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
