import Foundation

/// Conversor Markdown -> HTML autocontenido (sin dependencias externas).
/// Cubre el subconjunto útil para documentos: encabezados, párrafos, listas
/// anidadas, citas, reglas, bloques de código, tablas GFM y HTML embebido.
enum Markdown {

    static func html(from markdown: String) -> String {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: "    ")
        var lines = normalized.components(separatedBy: "\n")
        // Quita el front-matter YAML si existe.
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            lines.removeSubrange(0...end)
        }
        var index = 0
        return blocks(lines, &index, stopIndent: nil)
    }

    /// Primer encabezado nivel 1 (o el primer texto útil) para el <title>.
    static func title(from markdown: String) -> String {
        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("# ") {
                return inline(String(line.dropFirst(2)))
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return "Documento"
    }

    // MARK: - Bloques

    private static func blocks(_ lines: [String], _ i: inout Int, stopIndent: Int?) -> String {
        var out = ""
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { i += 1; continue }
            if let stop = stopIndent, indent(of: line) < stop { break }

            if let h = heading(line) { out += h; i += 1; continue }
            if isRule(line) { out += "<hr>\n"; i += 1; continue }
            if let fence = fenceMarker(line) { out += codeBlock(lines, &i, fence: fence); continue }
            if isQuote(line) { out += quote(lines, &i); continue }
            if listMarker(line) != nil { out += list(lines, &i); continue }
            if let table = table(lines, &i) { out += table; continue }
            if isHTMLBlock(line) { out += htmlBlock(lines, &i); continue }
            out += paragraph(lines, &i, stopIndent: stopIndent)
        }
        return out
    }

    private static func indent(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func heading(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        for ch in trimmed { if ch == "#" { level += 1 } else { break } }
        guard (1...6).contains(level) else { return nil }
        let rest = String(trimmed.dropFirst(level))
        guard rest.isEmpty || rest.hasPrefix(" ") else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") { text = String(text.dropLast()).trimmingCharacters(in: .whitespaces) }
        return "<h\(level)>\(inline(text))</h\(level)>\n"
    }

    private static func isRule(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.count >= 3, let first = t.first, "-*_".contains(first) else { return false }
        return t.allSatisfy { $0 == first || $0 == " " } && t.filter { $0 == first }.count >= 3
    }

    private static func fenceMarker(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("```") { return "```" }
        if t.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private static func codeBlock(_ lines: [String], _ i: inout Int, fence: String) -> String {
        let opener = lines[i].trimmingCharacters(in: .whitespaces)
        let language = String(opener.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
        i += 1
        var body: [String] = []
        while i < lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) { i += 1; break }
            body.append(lines[i]); i += 1
        }
        let cls = language.isEmpty ? "" : " class=\"language-\(escape(language))\""
        return "<pre><code\(cls)>\(escape(body.joined(separator: "\n")))</code></pre>\n"
    }

    private static func isQuote(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private static func quote(_ lines: [String], _ i: inout Int) -> String {
        var inner: [String] = []
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix(">") {
                var rest = String(t.dropFirst())
                if rest.hasPrefix(" ") { rest.removeFirst() }
                inner.append(rest)
                i += 1
            } else if t.isEmpty {
                break
            } else {
                inner.append(t); i += 1
            }
        }
        var j = 0
        return "<blockquote>\n" + blocks(inner, &j, stopIndent: nil) + "</blockquote>\n"
    }

    // MARK: - Listas

    private struct Marker {
        var indent: Int
        var ordered: Bool
        var start: Int
        var contentIndent: Int
        var rest: String
    }

    private static func listMarker(_ line: String) -> Marker? {
        let ind = indent(of: line)
        let body = String(line.dropFirst(ind))
        guard let first = body.first else { return nil }
        if "-*+".contains(first) {
            let after = body.dropFirst()
            guard after.first == " " else { return nil }
            let rest = String(after.drop { $0 == " " })
            guard !rest.isEmpty else { return nil }
            return Marker(indent: ind, ordered: false, start: 1, contentIndent: ind + 2, rest: rest)
        }
        if first.isNumber {
            let digits = body.prefix { $0.isNumber }
            let after = body.dropFirst(digits.count)
            guard let sep = after.first, sep == "." || sep == ")" else { return nil }
            let tail = after.dropFirst()
            guard tail.first == " " else { return nil }
            let rest = String(tail.drop { $0 == " " })
            guard !rest.isEmpty else { return nil }
            return Marker(indent: ind, ordered: true, start: Int(digits) ?? 1,
                          contentIndent: ind + digits.count + 2, rest: rest)
        }
        return nil
    }

    private static func list(_ lines: [String], _ i: inout Int) -> String {
        guard let first = listMarker(lines[i]) else { return "" }
        let baseIndent = first.indent
        let ordered = first.ordered
        var items: [[String]] = []
        var loose = false
        var pendingBlank = false

        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Una línea en blanco solo continúa la lista si el siguiente
                // bloque sigue perteneciendo a ella.
                var look = i + 1
                while look < lines.count, lines[look].trimmingCharacters(in: .whitespaces).isEmpty { look += 1 }
                guard look < lines.count else { i = lines.count; break }
                let next = lines[look]
                let belongs = (listMarker(next).map { $0.indent >= baseIndent && $0.ordered == ordered } ?? false)
                    || indent(of: next) > baseIndent
                if !belongs { break }
                pendingBlank = true
                i = look
                continue
            }
            if let marker = listMarker(line), marker.indent <= baseIndent {
                guard marker.ordered == ordered else { break }
                if pendingBlank { loose = true; pendingBlank = false }
                items.append([marker.rest])
                i += 1
                continue
            }
            guard !items.isEmpty else { break }
            if indent(of: line) > baseIndent || listMarker(line) != nil {
                if pendingBlank { loose = true; items[items.count - 1].append(""); pendingBlank = false }
                let strip = min(indent(of: line), first.contentIndent)
                items[items.count - 1].append(String(line.dropFirst(strip)))
                i += 1
                continue
            }
            break
        }

        var out = ordered
            ? (first.start == 1 ? "<ol>\n" : "<ol start=\"\(first.start)\">\n")
            : "<ul>\n"
        for item in items {
            var j = 0
            var html = blocks(item, &j, stopIndent: nil)
            if !loose {
                html = unwrapSingleParagraph(html)
            }
            out += "<li>" + html.trimmingCharacters(in: .whitespacesAndNewlines) + "</li>\n"
        }
        out += ordered ? "</ol>\n" : "</ul>\n"
        return out
    }

    /// Listas compactas: `<li><p>x</p></li>` -> `<li>x</li>`.
    private static func unwrapSingleParagraph(_ html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<p>") else { return html }
        guard let close = trimmed.range(of: "</p>") else { return html }
        let head = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 3)..<close.lowerBound])
        guard !head.contains("<p>") else { return html }
        let tail = String(trimmed[close.upperBound...])
        return head + tail
    }

    // MARK: - Tablas

    private static func table(_ lines: [String], _ i: inout Int) -> String? {
        guard i + 1 < lines.count else { return nil }
        let header = lines[i].trimmingCharacters(in: .whitespaces)
        let divider = lines[i + 1].trimmingCharacters(in: .whitespaces)
        guard header.contains("|"), !divider.isEmpty else { return nil }
        let dividerCells = splitRow(divider)
        guard !dividerCells.isEmpty else { return nil }
        let valid = dividerCells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" } && c.contains("-")
        }
        guard valid else { return nil }

        let aligns: [String] = dividerCells.map { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            if c.hasPrefix(":") && c.hasSuffix(":") { return " style=\"text-align:center\"" }
            if c.hasSuffix(":") { return " style=\"text-align:right\"" }
            if c.hasPrefix(":") { return " style=\"text-align:left\"" }
            return ""
        }

        var out = "<table>\n<thead>\n<tr>"
        for (n, cell) in splitRow(header).enumerated() {
            let a = n < aligns.count ? aligns[n] : ""
            out += "<th\(a)>\(inline(cell.trimmingCharacters(in: .whitespaces)))</th>"
        }
        out += "</tr>\n</thead>\n<tbody>\n"
        i += 2
        while i < lines.count {
            let row = lines[i].trimmingCharacters(in: .whitespaces)
            guard row.contains("|"), !row.isEmpty else { break }
            out += "<tr>"
            for (n, cell) in splitRow(row).enumerated() {
                let a = n < aligns.count ? aligns[n] : ""
                out += "<td\(a)>\(inline(cell.trimmingCharacters(in: .whitespaces)))</td>"
            }
            out += "</tr>\n"
            i += 1
        }
        return out + "</tbody>\n</table>\n"
    }

    private static func splitRow(_ row: String) -> [String] {
        var line = row
        if line.hasPrefix("|") { line.removeFirst() }
        if line.hasSuffix("|") && !line.hasSuffix("\\|") { line.removeLast() }
        var cells: [String] = []
        var current = ""
        var escaped = false
        for ch in line {
            if escaped { current.append(ch); escaped = false; continue }
            if ch == "\\" { escaped = true; current.append(ch); continue }
            if ch == "|" { cells.append(current); current = ""; continue }
            current.append(ch)
        }
        cells.append(current)
        return cells
    }

    // MARK: - HTML embebido y parrafos

    private static let blockTags: Set<String> = [
        "div", "section", "article", "header", "footer", "aside", "nav", "table",
        "figure", "figcaption", "blockquote", "pre", "ul", "ol", "dl", "hr", "p",
        "h1", "h2", "h3", "h4", "h5", "h6", "main", "form", "details", "iframe", "svg"
    ]

    private static func isHTMLBlock(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("<"), t.count > 1 else { return false }
        if t.hasPrefix("<!--") { return true }
        let name = t.dropFirst().drop { $0 == "/" }.prefix { $0.isLetter || $0.isNumber }
        return blockTags.contains(name.lowercased())
    }

    private static func htmlBlock(_ lines: [String], _ i: inout Int) -> String {
        var out: [String] = []
        while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(lines[i]); i += 1
        }
        return out.joined(separator: "\n") + "\n"
    }

    private static func paragraph(_ lines: [String], _ i: inout Int, stopIndent: Int?) -> String {
        var parts: [String] = []
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if let stop = stopIndent, indent(of: line) < stop { break }
            if !parts.isEmpty {
                if heading(line) != nil || isRule(line) || fenceMarker(line) != nil
                    || isQuote(line) || listMarker(line) != nil || isHTMLBlock(line) { break }
            }
            var text = line.trimmingCharacters(in: .whitespaces)
            if line.hasSuffix("  ") || line.hasSuffix("\\") {
                if text.hasSuffix("\\") { text.removeLast() }
                text += "<br>"
            }
            parts.append(text)
            i += 1
        }
        guard !parts.isEmpty else { return "" }
        return "<p>\(inline(parts.joined(separator: "\n")))</p>\n"
    }

    // MARK: - Inline

    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    private static func escapeText(_ text: String) -> String {
        // En texto corriente respetamos entidades ya escritas (&nbsp; &amp; ...).
        var out = ""
        let chars = Array(text)
        var k = 0
        while k < chars.count {
            let ch = chars[k]
            if ch == "&" {
                var j = k + 1
                var name = ""
                while j < chars.count, chars[j] != ";", name.count < 10,
                      chars[j].isLetter || chars[j].isNumber || chars[j] == "#" {
                    name.append(chars[j]); j += 1
                }
                if j < chars.count, chars[j] == ";", !name.isEmpty {
                    out += "&" + name + ";"
                    k = j + 1
                    continue
                }
                out += "&amp;"
            } else if ch == "<" {
                out += "&lt;"
            } else if ch == ">" {
                out += "&gt;"
            } else {
                out.append(ch)
            }
            k += 1
        }
        return out
    }

    static func inline(_ text: String) -> String {
        let chars = Array(text)
        var out = ""
        var buffer = ""
        var i = 0

        func flush() {
            if !buffer.isEmpty { out += escapeText(buffer); buffer = "" }
        }

        while i < chars.count {
            let ch = chars[i]

            // Escapes
            if ch == "\\", i + 1 < chars.count, "\\`*_{}[]()#+-.!|~<>".contains(chars[i + 1]) {
                buffer.append(chars[i + 1]); i += 2; continue
            }

            // Código en línea
            if ch == "`" {
                var run = 0
                while i + run < chars.count, chars[i + run] == "`" { run += 1 }
                if let close = findRun(chars, from: i + run, char: "`", length: run) {
                    flush()
                    let code = String(chars[(i + run)..<close]).trimmingCharacters(in: .whitespaces)
                    out += "<code>\(escape(code))</code>"
                    i = close + run
                    continue
                }
            }

            // Imagen
            if ch == "!", i + 1 < chars.count, chars[i + 1] == "[",
               let link = parseLink(chars, from: i + 1) {
                flush()
                out += "<img src=\"\(escape(link.url))\" alt=\"\(escape(link.text))\""
                    + (link.title.isEmpty ? "" : " title=\"\(escape(link.title))\"") + ">"
                i = link.end
                continue
            }

            // Enlace
            if ch == "[", let link = parseLink(chars, from: i) {
                flush()
                out += "<a href=\"\(escape(link.url))\""
                    + (link.title.isEmpty ? "" : " title=\"\(escape(link.title))\"")
                    + ">\(inline(link.text))</a>"
                i = link.end
                continue
            }

            // Autolink y HTML en línea
            if ch == "<", let close = chars[i...].firstIndex(of: ">") {
                let content = String(chars[(i + 1)..<close])
                if content.hasPrefix("http://") || content.hasPrefix("https://") {
                    flush()
                    out += "<a href=\"\(escape(content))\">\(escape(content))</a>"
                    i = close + 1
                    continue
                }
                if content.contains("@"), !content.contains(" ") {
                    flush()
                    out += "<a href=\"mailto:\(escape(content))\">\(escape(content))</a>"
                    i = close + 1
                    continue
                }
                let name = content.drop { $0 == "/" }.prefix { $0.isLetter || $0.isNumber }
                if !name.isEmpty || content.hasPrefix("!--") {
                    flush()
                    out += "<" + content + ">"
                    i = close + 1
                    continue
                }
            }

            // Énfasis
            if ch == "*" || ch == "_" || ch == "~" {
                var run = 0
                while i + run < chars.count, chars[i + run] == ch { run += 1 }
                let usable = ch == "~" ? min(run, 2) : min(run, 3)
                if canOpen(chars, at: i, run: usable, char: ch),
                   let close = findCloser(chars, from: i + usable, char: ch, length: usable) {
                    flush()
                    let inner = inline(String(chars[(i + usable)..<close]))
                    switch (ch, usable) {
                    case ("~", 2): out += "<del>\(inner)</del>"
                    case ("~", _): out += "~\(inner)~"
                    case (_, 3): out += "<strong><em>\(inner)</em></strong>"
                    case (_, 2): out += "<strong>\(inner)</strong>"
                    default: out += "<em>\(inner)</em>"
                    }
                    i = close + usable
                    continue
                }
            }

            buffer.append(ch)
            i += 1
        }
        flush()
        return out
    }

    private static func canOpen(_ chars: [Character], at i: Int, run: Int, char: Character) -> Bool {
        let next = i + run < chars.count ? chars[i + run] : nil
        guard let n = next, !n.isWhitespace else { return false }
        guard char == "_" else { return true }
        // `_` no rompe palabras (snake_case).
        let prev = i > 0 ? chars[i - 1] : nil
        if let p = prev, p.isLetter || p.isNumber { return false }
        return true
    }

    private static func findRun(_ chars: [Character], from: Int, char: Character, length: Int) -> Int? {
        var i = from
        while i < chars.count {
            if chars[i] == char {
                var run = 0
                while i + run < chars.count, chars[i + run] == char { run += 1 }
                if run == length { return i }
                i += run
            } else {
                i += 1
            }
        }
        return nil
    }

    private static func findCloser(_ chars: [Character], from: Int, char: Character, length: Int) -> Int? {
        var i = from
        while i < chars.count {
            if chars[i] == "\\" { i += 2; continue }
            if chars[i] == char {
                var run = 0
                while i + run < chars.count, chars[i + run] == char { run += 1 }
                let prev = i > 0 ? chars[i - 1] : nil
                let closes = run >= length && !(prev?.isWhitespace ?? true)
                if closes {
                    if char == "_" {
                        let after = i + run < chars.count ? chars[i + run] : nil
                        if let a = after, a.isLetter || a.isNumber { i += run; continue }
                    }
                    return i
                }
                i += run
            } else {
                i += 1
            }
        }
        return nil
    }

    private struct Link { var text: String; var url: String; var title: String; var end: Int }

    private static func parseLink(_ chars: [Character], from: Int) -> Link? {
        guard chars[from] == "[" else { return nil }
        var depth = 0
        var i = from
        var close = -1
        while i < chars.count {
            if chars[i] == "\\" { i += 2; continue }
            if chars[i] == "[" { depth += 1 }
            if chars[i] == "]" {
                depth -= 1
                if depth == 0 { close = i; break }
            }
            i += 1
        }
        guard close > from, close + 1 < chars.count, chars[close + 1] == "(" else { return nil }
        var j = close + 2
        var depthParen = 1
        var target = ""
        while j < chars.count {
            if chars[j] == "\\" , j + 1 < chars.count { target.append(chars[j + 1]); j += 2; continue }
            if chars[j] == "(" { depthParen += 1 }
            if chars[j] == ")" {
                depthParen -= 1
                if depthParen == 0 { break }
            }
            target.append(chars[j])
            j += 1
        }
        guard j < chars.count else { return nil }

        var url = target.trimmingCharacters(in: .whitespaces)
        var title = ""
        if let range = url.range(of: " \""), url.hasSuffix("\"") {
            title = String(url[range.upperBound...].dropLast())
            url = String(url[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if url.hasPrefix("<") && url.hasSuffix(">") { url = String(url.dropFirst().dropLast()) }
        let text = String(chars[(from + 1)..<close])
        return Link(text: text, url: url, title: title, end: j + 1)
    }
}
