import SwiftUI

enum Theme {
    static let sidebarWidth: CGFloat = 252
    static let corner: CGFloat = 8

    static var canvas: Color { Color(nsColor: .textBackgroundColor) }
    static var sidebar: Color { Color(nsColor: .underPageBackgroundColor) }
    static var hairline: Color { Color(nsColor: .separatorColor) }
    static var faint: Color { Color(nsColor: .tertiaryLabelColor) }

    static func editorFont(size: CGFloat = 13) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func proseFont(size: CGFloat = 14) -> NSFont {
        if let font = NSFont(name: "SF Mono", size: size) { return font }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

/// Fondo translúcido nativo para la barra lateral.
struct SidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Botón primario monocromo, sin adornos.
struct PrimaryButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(prominent ? Color.primary : Color.primary.opacity(0.06))
            )
            .foregroundStyle(prominent ? Color(nsColor: .textBackgroundColor) : Color.primary)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Botón discreto para barras y toolbars.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .foregroundStyle(.primary)
    }
}
