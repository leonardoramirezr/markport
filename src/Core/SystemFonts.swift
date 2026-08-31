import AppKit
import Foundation

/// Fonts available on the system and verification of the ones a CSS uses.
enum SystemFonts {

    static let generic: Set<String> = [
        "serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui",
        "ui-serif", "ui-sans-serif", "ui-monospace", "ui-rounded", "math", "emoji",
        "fangsong", "inherit", "initial", "unset", "revert", "-apple-system",
        "blinkmacsystemfont", "-webkit-body"
    ]

    static var families: [String] {
        NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private static var lowercasedFamilies: Set<String> {
        Set(NSFontManager.shared.availableFontFamilies.map { $0.lowercased() })
    }

    static func isAvailable(_ name: String) -> Bool {
        let clean = normalize(name)
        if clean.isEmpty || generic.contains(clean) { return true }
        if lowercasedFamilies.contains(clean) { return true }
        return NSFont(name: name.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")), size: 12) != nil
    }

    /// Families referenced in the CSS that are neither installed nor bundled via @font-face.
    static func missingFamilies(in css: String) -> [String] {
        let (body, bundled) = stripFontFaces(css)
        var missing: [String] = []
        var seen = Set<String>()
        for declaration in declarations(named: "font-family", in: body) {
            for token in declaration.components(separatedBy: ",") {
                let name = token.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\"'"))
                guard !name.isEmpty, !name.hasPrefix("var("), !name.hasPrefix("--") else { continue }
                let key = normalize(name)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                if bundled.contains(key) || isAvailable(name) { continue }
                missing.append(name)
            }
        }
        return missing
    }

    /// Families declared with @font-face (files that ship with the style).
    private static func stripFontFaces(_ css: String) -> (String, Set<String>) {
        var body = ""
        var bundled = Set<String>()
        var rest = Substring(css)
        while let start = rest.range(of: "@font-face", options: .caseInsensitive) {
            body += rest[rest.startIndex..<start.lowerBound]
            guard let open = rest[start.upperBound...].firstIndex(of: "{") else {
                rest = rest[start.upperBound...]
                break
            }
            var depth = 0
            var index = open
            var end: Substring.Index?
            while index < rest.endIndex {
                if rest[index] == "{" { depth += 1 }
                if rest[index] == "}" {
                    depth -= 1
                    if depth == 0 { end = rest.index(after: index); break }
                }
                index = rest.index(after: index)
            }
            let block = String(rest[open..<(end ?? rest.endIndex)])
            for declaration in declarations(named: "font-family", in: block) {
                let name = declaration.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\"';"))
                bundled.insert(normalize(name))
            }
            rest = rest[(end ?? rest.endIndex)...]
        }
        body += rest
        return (body, bundled)
    }

    private static func declarations(named property: String, in css: String) -> [String] {
        var results: [String] = []
        var rest = Substring(css)
        while let range = rest.range(of: property, options: .caseInsensitive) {
            let after = rest[range.upperBound...]
            guard let colon = after.firstIndex(where: { !$0.isWhitespace }), after[colon] == ":" else {
                rest = after
                continue
            }
            let valueStart = after.index(after: colon)
            let terminator = after[valueStart...].firstIndex(where: { $0 == ";" || $0 == "}" }) ?? after.endIndex
            results.append(String(after[valueStart..<terminator]))
            rest = after[terminator...]
        }
        return results
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\"';")).lowercased()
    }

    /// Declaration ready to paste into the CSS.
    static func declaration(for family: String) -> String {
        let fallback: String
        if let font = NSFont(name: family, size: 12), font.isFixedPitch {
            fallback = "Menlo, \"Courier New\", monospace"
        } else if family.lowercased().contains("serif") || isSerif(family) {
            fallback = "Georgia, \"Times New Roman\", serif"
        } else {
            fallback = "\"Helvetica Neue\", Helvetica, Arial, sans-serif"
        }
        return "font-family: \"\(family)\", \(fallback);"
    }

    private static func isSerif(_ family: String) -> Bool {
        guard let descriptor = NSFont(name: family, size: 12)?.fontDescriptor else { return false }
        // Serif typographic classes per CoreText (bits 28-31).
        let serifClasses: Set<UInt32> = [1, 2, 3, 4, 5, 7]
        let fontClass = (descriptor.symbolicTraits.rawValue & 0xF000_0000) >> 28
        return serifClasses.contains(fontClass)
    }
}
