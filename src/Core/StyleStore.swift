import Foundation
import SwiftUI

/// Un estilo = una carpeta con `style.css`, `template.html`, `meta.json`
/// y los recursos relativos (por ejemplo `fonts/`) que el CSS referencie.
struct DocStyle: Identifiable, Equatable {
    var id: String
    var name: String
    var css: String
    var html: String
    var updatedAt: Date

    var folder: URL { StyleStore.stylesRoot.appendingPathComponent(id, isDirectory: true) }
    var cssURL: URL { folder.appendingPathComponent("style.css") }
    var htmlURL: URL { folder.appendingPathComponent("template.html") }
    var page: PageSetup { PageSetup.parse(css: css) }

    /// Huella del contenido: invalida miniaturas cuando algo cambia.
    var fingerprint: String {
        var hasher = Hasher()
        hasher.combine(css)
        hasher.combine(html)
        return String(UInt(bitPattern: hasher.finalize()), radix: 36)
    }

    static func new(name: String) -> DocStyle {
        DocStyle(id: UUID().uuidString,
                 name: name,
                 css: DefaultAssets.css,
                 html: DefaultAssets.templateHTML,
                 updatedAt: Date())
    }
}

@MainActor
final class StyleStore: ObservableObject {
    @Published private(set) var styles: [DocStyle] = []

    nonisolated static let support: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Markport", isDirectory: true)
    }()
    nonisolated static let stylesRoot = support.appendingPathComponent("Styles", isDirectory: true)
    nonisolated static let cacheRoot = support.appendingPathComponent("Cache", isDirectory: true)

    init() {
        try? FileManager.default.createDirectory(at: Self.stylesRoot, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: Self.cacheRoot, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(at: Self.stylesRoot,
                                                   includingPropertiesForKeys: nil,
                                                   options: [.skipsHiddenFiles])) ?? []
        var loaded: [DocStyle] = []
        for folder in folders {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let cssURL = folder.appendingPathComponent("style.css")
            guard let css = try? String(contentsOf: cssURL, encoding: .utf8) else { continue }
            let html = (try? String(contentsOf: folder.appendingPathComponent("template.html"), encoding: .utf8))
                ?? DefaultAssets.templateHTML
            var name = folder.lastPathComponent
            var updated = Date.distantPast
            if let data = try? Data(contentsOf: folder.appendingPathComponent("meta.json")),
               let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                name = (meta["name"] as? String) ?? name
                if let ts = meta["updatedAt"] as? Double { updated = Date(timeIntervalSince1970: ts) }
            }
            loaded.append(DocStyle(id: folder.lastPathComponent, name: name,
                                   css: css, html: html, updatedAt: updated))
        }
        styles = loaded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func save(_ style: DocStyle) -> DocStyle {
        var copy = style
        copy.updatedAt = Date()
        let fm = FileManager.default
        try? fm.createDirectory(at: copy.folder, withIntermediateDirectories: true)
        try? copy.css.write(to: copy.cssURL, atomically: true, encoding: .utf8)
        try? copy.html.write(to: copy.htmlURL, atomically: true, encoding: .utf8)
        let meta: [String: Any] = ["name": copy.name, "updatedAt": copy.updatedAt.timeIntervalSince1970]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? data.write(to: copy.folder.appendingPathComponent("meta.json"))
        }
        if let index = styles.firstIndex(where: { $0.id == copy.id }) {
            styles[index] = copy
        } else {
            styles.append(copy)
        }
        styles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return copy
    }

    func delete(_ style: DocStyle) {
        try? FileManager.default.removeItem(at: style.folder)
        styles.removeAll { $0.id == style.id }
    }

    func duplicate(_ style: DocStyle) -> DocStyle {
        var copy = style
        copy.id = UUID().uuidString
        copy.name = uniqueName(base: style.name + " copia")
        try? FileManager.default.createDirectory(at: copy.folder, withIntermediateDirectories: true)
        // Arrastra los recursos (fuentes, imágenes) del estilo original.
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: style.folder, includingPropertiesForKeys: nil)) ?? []
        for item in items where !["style.css", "template.html", "meta.json"].contains(item.lastPathComponent) {
            try? fm.copyItem(at: item, to: copy.folder.appendingPathComponent(item.lastPathComponent))
        }
        return save(copy)
    }

    func uniqueName(base: String) -> String {
        var candidate = base
        var n = 2
        while styles.contains(where: { $0.name.lowercased() == candidate.lowercased() }) {
            candidate = "\(base) \(n)"
            n += 1
        }
        return candidate
    }

    /// Copia recursos (por ejemplo `.woff2`) a la carpeta del estilo.
    @discardableResult
    func importResource(_ url: URL, into style: DocStyle, subfolder: String? = nil) -> String? {
        let fm = FileManager.default
        var destinationFolder = style.folder
        if let subfolder, !subfolder.isEmpty {
            destinationFolder = destinationFolder.appendingPathComponent(subfolder, isDirectory: true)
        }
        try? fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let destination = destinationFolder.appendingPathComponent(url.lastPathComponent)
        try? fm.removeItem(at: destination)
        do {
            try fm.copyItem(at: url, to: destination)
        } catch {
            return nil
        }
        if let subfolder, !subfolder.isEmpty { return "\(subfolder)/\(url.lastPathComponent)" }
        return url.lastPathComponent
    }
}
