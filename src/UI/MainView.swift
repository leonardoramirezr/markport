import AppKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var store: StyleStore
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            StyleSidebar()
                .frame(width: Theme.sidebarWidth)
            Divider()
            EditorPane()
        }
        .background(Theme.canvas)
        .ignoresSafeArea()
    }
}

// MARK: - Barra de estilos

struct StyleSidebar: View {
    @EnvironmentObject private var store: StyleStore
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var previews: PreviewCache
    @State private var renaming: DocStyle?
    @State private var renameText = ""

    private var selectedID: String? { state.style(in: store)?.id }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Estilos")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    state.editing = DocStyle.new(name: store.uniqueName(base: "Estilo"))
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Nuevo estilo (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 22) {
                    ForEach(store.styles) { style in
                        StyleCard(style: style, isSelected: style.id == selectedID)
                            .onTapGesture { state.selectedStyleID = style.id }
                            .contextMenu {
                                Button("Editar…") { state.editing = style }
                                Button("Duplicar") { _ = store.duplicate(style) }
                                Button("Renombrar…") { renaming = style; renameText = style.name }
                                Button("Mostrar en Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([style.folder])
                                }
                                Divider()
                                Button("Eliminar", role: .destructive) {
                                    if state.selectedStyleID == style.id { state.selectedStyleID = nil }
                                    store.delete(style)
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(SidebarBackground().ignoresSafeArea())
        .sheet(item: $renaming) { style in
            RenameSheet(name: $renameText) { newName in
                var copy = style
                copy.name = newName
                store.save(copy)
            }
        }
    }
}

struct StyleCard: View {
    let style: DocStyle
    let isSelected: Bool
    @EnvironmentObject private var previews: PreviewCache

    private var aspect: CGFloat {
        let page = style.page.paperSize
        return page.height > 0 ? page.width / page.height : 0.707
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white)
                if let image = previews.image(for: style) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(0.5)
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Theme.hairline,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)

            HStack(spacing: 5) {
                Text(style.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(style.page.label)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
            }
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Editor de Markdown

struct EditorPane: View {
    @EnvironmentObject private var store: StyleStore
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CodeTextView(initialText: state.markdown,
                         font: Theme.proseFont(size: 13.5),
                         controller: state.markdownController,
                         padding: 26,
                         lineHeight: 1.45) { text in
                state.markdownChanged(text)
            }
            .background(Theme.canvas)

            if let message = state.message {
                Toast(message: message) { state.message = nil }
                    .padding(.trailing, 22)
                    .padding(.bottom, 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Button {
                    state.showingPreview = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "eye").font(.system(size: 12, weight: .medium))
                        Text("Vista previa")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(prominent: false))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                .help("Vista previa del documento (⌘P)")

                Button {
                    state.export(store: store)
                } label: {
                    HStack(spacing: 7) {
                        if state.isExporting {
                            ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.down.doc").font(.system(size: 12, weight: .medium))
                        }
                        Text(state.isExporting ? "Exportando…" : "Exportar PDF")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(state.isExporting)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
                .help("Exportar a PDF con el estilo seleccionado (⌘E)")
            }
            .padding(22)
        }
        .animation(.easeOut(duration: 0.18), value: state.message?.id)
        .sheet(isPresented: $state.showingPreview) {
            if let style = state.style(in: store) {
                DocumentPreviewView(style: style, markdown: previewMarkdown)
            }
        }
    }

    private var previewMarkdown: String {
        state.markdownController.text.isEmpty ? state.markdown : state.markdownController.text
    }
}

struct Toast: View {
    let message: AppState.Message
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.isError ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(message.isError ? .orange : .green)
            Text(message.text)
                .font(.system(size: 12))
                .lineLimit(2)
            if let url = message.fileURL {
                Button("Mostrar") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .buttonStyle(QuietButtonStyle())
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
        )
        .frame(maxWidth: 420)
        .task(id: message.id) {
            guard !message.isError else { return }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            dismiss()
        }
    }
}

struct RenameSheet: View {
    @Binding var name: String
    @Environment(\.dismiss) private var dismiss
    let commit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Renombrar estilo").font(.system(size: 13, weight: .semibold))
            TextField("Nombre", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.buttonStyle(QuietButtonStyle())
                Button("Guardar") {
                    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty { commit(clean) }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
