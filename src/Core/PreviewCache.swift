import AppKit
import SwiftUI

/// Miniaturas de estilos en formato página. Se generan de una en una fuera de
/// pantalla, se memorizan en RAM y se guardan en disco para arranques rápidos.
@MainActor
final class PreviewCache: ObservableObject {
    @Published private(set) var images: [String: NSImage] = [:]

    private lazy var renderer = WebRenderer()
    private var inFlight = Set<String>()
    private var queue: [DocStyle] = []
    private var working = false
    private let width: CGFloat = 320

    private func key(_ style: DocStyle) -> String { "\(style.id)-\(style.fingerprint)" }

    private func diskURL(_ key: String) -> URL {
        StyleStore.cacheRoot.appendingPathComponent("\(key).png")
    }

    /// Lectura pura: no muta estado durante el dibujado de SwiftUI.
    func image(for style: DocStyle) -> NSImage? {
        if let image = images[key(style)] { return image }
        DispatchQueue.main.async { [weak self] in self?.request(style) }
        return nil
    }

    func invalidate(_ style: DocStyle) {
        images.removeValue(forKey: key(style))
        try? FileManager.default.removeItem(at: diskURL(key(style)))
        request(style)
    }

    func request(_ style: DocStyle) {
        let k = key(style)
        guard images[k] == nil, !inFlight.contains(k) else { return }
        inFlight.insert(k)
        queue.append(style)
        drain()
    }

    private func drain() {
        guard !working, !queue.isEmpty else { return }
        working = true
        let style = queue.removeFirst()
        Task { [weak self] in
            guard let self else { return }
            let k = self.key(style)
            if let data = try? Data(contentsOf: self.diskURL(k)), let cached = NSImage(data: data) {
                self.images[k] = cached
            } else if let image = try? await self.renderer.snapshot(markdown: DefaultAssets.sampleMarkdown,
                                                                    style: style,
                                                                    width: self.width) {
                self.images[k] = image
                self.persist(image, key: k, styleID: style.id)
            }
            self.inFlight.remove(k)
            self.working = false
            self.drain()
        }
    }

    private func persist(_ image: NSImage, key: String, styleID: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        // Limpia miniaturas antiguas del mismo estilo.
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: StyleStore.cacheRoot, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(styleID) && file.lastPathComponent != "\(key).png" {
            try? fm.removeItem(at: file)
        }
        try? png.write(to: diskURL(key))
    }
}
