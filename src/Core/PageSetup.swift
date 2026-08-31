import AppKit
import Foundation

/// Translates the user's CSS `@page` rule into an `NSPrintInfo`,
/// so the PDF respects the size and margins declared in the stylesheet.
struct PageSetup: Equatable {
    var paperSize: NSSize          // in points (1pt = 1/72")
    var top: CGFloat
    var right: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var landscape: Bool
    var label: String

    static let a4 = PageSetup(paperSize: NSSize(width: 595.28, height: 841.89),
                              top: 56.7, right: 56.7, bottom: 56.7, left: 56.7,
                              landscape: false, label: "A4")

    var contentSize: NSSize {
        NSSize(width: max(72, paperSize.width - left - right),
               height: max(72, paperSize.height - top - bottom))
    }

    static let namedSizes: [String: NSSize] = [
        "a3": NSSize(width: 841.89, height: 1190.55),
        "a4": NSSize(width: 595.28, height: 841.89),
        "a5": NSSize(width: 419.53, height: 595.28),
        "letter": NSSize(width: 612, height: 792),
        "legal": NSSize(width: 612, height: 1008),
        "tabloid": NSSize(width: 792, height: 1224),
        "executive": NSSize(width: 521.86, height: 756)
    ]

    /// Reads the first `@page { ... }` block from the CSS.
    static func parse(css: String) -> PageSetup {
        var setup = PageSetup.a4
        guard let block = firstAtPageBlock(in: css) else { return setup }

        var declarations: [String: String] = [:]
        for chunk in block.components(separatedBy: ";") {
            let parts = chunk.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, !parts[0].isEmpty else { continue }
            declarations[parts[0].lowercased()] = parts[1]
        }

        if let size = declarations["size"] {
            let tokens = size.lowercased()
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            var lengths: [CGFloat] = []
            var named: NSSize?
            var landscape = false
            var label = ""
            for token in tokens {
                if token == "landscape" { landscape = true; continue }
                if token == "portrait" { continue }
                if let match = namedSizes[token] { named = match; label = token.capitalized; continue }
                if let value = length(token) { lengths.append(value) }
            }
            if lengths.count >= 2 {
                setup.paperSize = NSSize(width: lengths[0], height: lengths[1])
                setup.label = "Custom"
            } else if lengths.count == 1 {
                setup.paperSize = NSSize(width: lengths[0], height: lengths[0])
                setup.label = "Custom"
            } else if let named {
                setup.paperSize = named
                setup.label = label
            }
            if landscape {
                setup.landscape = true
                setup.paperSize = NSSize(width: max(setup.paperSize.width, setup.paperSize.height),
                                         height: min(setup.paperSize.width, setup.paperSize.height))
            }
        }

        if let margin = declarations["margin"] {
            let values = margin.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .compactMap { length($0.lowercased()) }
            switch values.count {
            case 1: setup.top = values[0]; setup.right = values[0]; setup.bottom = values[0]; setup.left = values[0]
            case 2: setup.top = values[0]; setup.bottom = values[0]; setup.right = values[1]; setup.left = values[1]
            case 3: setup.top = values[0]; setup.right = values[1]; setup.left = values[1]; setup.bottom = values[2]
            case 4: setup.top = values[0]; setup.right = values[1]; setup.bottom = values[2]; setup.left = values[3]
            default: break
            }
        }
        if let v = declarations["margin-top"], let n = length(v.lowercased()) { setup.top = n }
        if let v = declarations["margin-right"], let n = length(v.lowercased()) { setup.right = n }
        if let v = declarations["margin-bottom"], let n = length(v.lowercased()) { setup.bottom = n }
        if let v = declarations["margin-left"], let n = length(v.lowercased()) { setup.left = n }
        return setup
    }

    private static func firstAtPageBlock(in css: String) -> String? {
        guard let start = css.range(of: "@page", options: .caseInsensitive),
              let open = css[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < css.endIndex {
            if css[index] == "{" { depth += 1 }
            if css[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(css[css.index(after: open)..<index])
                }
            }
            index = css.index(after: index)
        }
        return nil
    }

    /// Converts a CSS length to points.
    static func length(_ token: String) -> CGFloat? {
        let text = token.trimmingCharacters(in: .whitespaces).lowercased()
        let units: [(String, CGFloat)] = [
            ("mm", 72.0 / 25.4), ("cm", 72.0 / 2.54), ("in", 72.0),
            ("pt", 1.0), ("px", 0.75), ("pc", 12.0), ("q", 72.0 / 101.6)
        ]
        for (suffix, factor) in units where text.hasSuffix(suffix) {
            guard let value = Double(text.dropLast(suffix.count)) else { return nil }
            return CGFloat(value) * factor
        }
        if let value = Double(text) { return CGFloat(value) }  // no unit -> CSS px
        return nil
    }

    func printInfo(savingTo url: URL?) -> NSPrintInfo {
        let info = NSPrintInfo(dictionary: [:])
        info.paperSize = paperSize
        info.topMargin = top
        info.bottomMargin = bottom
        info.leftMargin = left
        info.rightMargin = right
        info.orientation = paperSize.width > paperSize.height ? .landscape : .portrait
        info.horizontalPagination = .automatic
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.scalingFactor = 1.0
        if let url {
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url as NSURL
        }
        return info
    }
}
