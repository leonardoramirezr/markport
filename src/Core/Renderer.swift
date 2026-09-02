import Foundation

enum Renderer {

    /// Assembles the style's HTML template with the HTML derived from the Markdown.
    static func document(markdown: String, style: DocStyle, extraHead: String = "") -> String {
        let content = Markdown.html(from: markdown)
        let title = Markdown.title(from: markdown)
        var html = style.html.isEmpty ? DefaultAssets.templateHTML : style.html

        var injected = false
        for token in ["{{ content }}", "{{content}}", "{{ contenido }}", "{{contenido}}"]
        where html.contains(token) {
            html = html.replacingOccurrences(of: token, with: content)
            injected = true
        }
        for token in ["{{ title }}", "{{title}}", "{{ titulo }}", "{{titulo}}"] {
            html = html.replacingOccurrences(of: token, with: Markdown.escape(title))
        }
        if !injected {
            // Template without a marker: inject the content inside the body.
            if let range = html.range(of: "</body>", options: .caseInsensitive) {
                html.replaceSubrange(range, with: "<article class=\"doc\">\n\(content)\n</article>\n</body>")
            } else {
                html += "\n<article class=\"doc\">\n\(content)\n</article>\n"
            }
        }

        // WebKit's print engine drops CSS background colors by default (an
        // ink-saving convention); without this, `html`/`body` backgrounds
        // that render fine on screen turn white in the exported PDF.
        var head = "<style id=\"markport-print-color\">html,body{-webkit-print-color-adjust:exact;print-color-adjust:exact;}</style>\n" + extraHead
        let lower = html.lowercased()
        if !lower.contains("rel=\"stylesheet\"") && !lower.contains("rel='stylesheet'") && !lower.contains("<style") {
            head = "<link rel=\"stylesheet\" href=\"style.css\">\n" + head
        }
        if !head.isEmpty {
            if let range = html.range(of: "</head>", options: .caseInsensitive) {
                html.replaceSubrange(range, with: head + "\n</head>")
            } else {
                html = head + "\n" + html
            }
        }
        return html
    }

    /// Sheet name used by previews: keeps the draft CSS
    /// separate from the saved `style.css`, so Cancel leaves no trace.
    static let draftCSSName = ".markport-draft.css"

    /// Writes the document inside the style's folder so relative paths
    /// (`style.css`, `fonts/...`) resolve the same way as on disk.
    @discardableResult
    static func writeRenderFile(markdown: String,
                                style: DocStyle,
                                filename: String,
                                cssFilename: String = "style.css",
                                extraHead: String = "") throws -> URL {
        try FileManager.default.createDirectory(at: style.folder, withIntermediateDirectories: true)
        // The sheet must exist alongside the document for the relative `href` to resolve.
        let cssURL = style.folder.appendingPathComponent(cssFilename)
        try style.css.write(to: cssURL, atomically: true, encoding: .utf8)

        var html = document(markdown: markdown, style: style, extraHead: extraHead)
        if cssFilename != "style.css" {
            html = html.replacingOccurrences(of: "style.css", with: cssFilename)
        }
        // Cache-bust the stylesheet reference: the style editor keeps a single
        // WKWebView alive and reloads this same-named file on every CSS edit,
        // and WebKit can otherwise keep serving the previous CSS content.
        if let regex = try? NSRegularExpression(
            pattern: "(href=[\"'])\(NSRegularExpression.escapedPattern(for: cssFilename))([\"'])")
        {
            let range = NSRange(html.startIndex..., in: html)
            let bust = "$1\(cssFilename)?v=\(abs(style.css.hashValue))$2"
            html = regex.stringByReplacingMatches(in: html, range: range, withTemplate: bust)
        }
        let url = style.folder.appendingPathComponent(filename)
        try html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Deletes the working files left behind by previews.
    static func removeTemporaryFiles(in style: DocStyle) {
        let fm = FileManager.default
        for name in [".markport-live.html", ".markport-preview.html",
                     ".markport-export.html", draftCSSName] {
            try? fm.removeItem(at: style.folder.appendingPathComponent(name))
        }
    }

    /// Screen-only CSS that simulates the `@page` margins in the preview.
    static func previewHead(page: PageSetup) -> String {
        """
        <style id="markport-preview">
        @media screen {
          body { padding: \(page.top)pt \(page.right)pt \(page.bottom)pt \(page.left)pt; }
        }
        </style>
        """
    }
}
