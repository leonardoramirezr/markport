import SwiftUI

/// Full-page preview of the document with the selected style,
/// shown in a separate sheet before exporting to PDF.
struct DocumentPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let style: DocStyle
    let markdown: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(style.name)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.faint)
                .padding(.leading, 10)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            GeometryReader { geo in
                let width = min(geo.size.width - 48, style.page.paperSize.width)
                StylePreviewWeb(style: style, markdown: markdown, targetWidth: width)
                    .frame(width: width, height: geo.size.height - 24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            }
            .background(Theme.sidebar)
        }
        .frame(width: 760, height: 860)
        .background(Theme.canvas)
    }
}
