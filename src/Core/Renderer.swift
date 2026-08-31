import Foundation

enum Renderer {

    /// Ensambla la plantilla HTML del estilo con el HTML derivado del Markdown.
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
            // Plantilla sin marcador: inyectamos el contenido dentro del body.
            if let range = html.range(of: "</body>", options: .caseInsensitive) {
                html.replaceSubrange(range, with: "<article class=\"doc\">\n\(content)\n</article>\n</body>")
            } else {
                html += "\n<article class=\"doc\">\n\(content)\n</article>\n"
            }
        }

        var head = extraHead
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

    /// Nombre de hoja usado por las vistas previas: mantiene el CSS borrador
    /// separado del `style.css` guardado, para que Cancelar no deje rastro.
    static let draftCSSName = ".markport-draft.css"

    /// Escribe el documento dentro de la carpeta del estilo para que las rutas
    /// relativas (`style.css`, `fonts/...`) resuelvan igual que en disco.
    @discardableResult
    static func writeRenderFile(markdown: String,
                                style: DocStyle,
                                filename: String,
                                cssFilename: String = "style.css",
                                extraHead: String = "") throws -> URL {
        try FileManager.default.createDirectory(at: style.folder, withIntermediateDirectories: true)
        // La hoja debe existir junto al documento para que `href` relativo resuelva.
        let cssURL = style.folder.appendingPathComponent(cssFilename)
        try style.css.write(to: cssURL, atomically: true, encoding: .utf8)

        var html = document(markdown: markdown, style: style, extraHead: extraHead)
        if cssFilename != "style.css" {
            html = html.replacingOccurrences(of: "style.css", with: cssFilename)
        }
        let url = style.folder.appendingPathComponent(filename)
        try html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Borra los archivos de trabajo que dejan las vistas previas.
    static func removeTemporaryFiles(in style: DocStyle) {
        let fm = FileManager.default
        for name in [".markport-live.html", ".markport-preview.html",
                     ".markport-export.html", draftCSSName] {
            try? fm.removeItem(at: style.folder.appendingPathComponent(name))
        }
    }

    /// CSS solo-pantalla que simula los márgenes de `@page` en la vista previa.
    static func previewHead(page: PageSetup) -> String {
        """
        <style id="markport-preview">
        @media screen {
          html { background: #ffffff; }
          body { padding: \(page.top)pt \(page.right)pt \(page.bottom)pt \(page.left)pt; }
        }
        </style>
        """
    }
}
