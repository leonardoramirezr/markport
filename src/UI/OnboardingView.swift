import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @EnvironmentObject private var store: StyleStore
    @EnvironmentObject private var state: AppState
    @State private var name = "Mi estilo"

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 10) {
                    Text("Markport")
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.5)
                    Text("Markdown a PDF con tus propios estilos.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 34)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Para empezar, define un estilo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("Nombre del estilo", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .onSubmit(create)

                    HStack(spacing: 10) {
                        Button("Crear estilo", action: create)
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Importar CSS…", action: importCSS)
                            .buttonStyle(PrimaryButtonStyle(prominent: false))
                    }
                    .padding(.top, 2)

                    Text("Un estilo son dos archivos: una hoja CSS y una plantilla HTML con {{ title }} y {{ content }}. Podrás editarlos cuando quieras.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .frame(width: 380)
                Spacer()
                Spacer()
            }
        }
    }

    private func create() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var style = DocStyle.new(name: store.uniqueName(base: clean.isEmpty ? "Estilo" : clean))
        style.css = DefaultAssets.css
        state.editing = style
    }

    private func importCSS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "css") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.title = "Elegir hoja de estilo"
        guard panel.runModal() == .OK, let url = panel.url,
              let css = try? String(contentsOf: url, encoding: .utf8) else { return }
        let base = url.deletingPathExtension().lastPathComponent
        var style = DocStyle.new(name: store.uniqueName(base: base))
        style.css = css
        // Arrastra recursos vecinos (por ejemplo la carpeta `fonts/`).
        let neighbour = url.deletingLastPathComponent().appendingPathComponent("fonts", isDirectory: true)
        if FileManager.default.fileExists(atPath: neighbour.path) {
            try? FileManager.default.createDirectory(at: style.folder, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: neighbour, to: style.folder.appendingPathComponent("fonts"))
        }
        state.editing = style
    }
}
