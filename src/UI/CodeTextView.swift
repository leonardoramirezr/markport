import AppKit
import SwiftUI

/// Puente hacia el NSTextView para insertar texto en el cursor
/// y leer el contenido sin pasar por SwiftUI en cada tecla.
final class EditorController: ObservableObject {
    weak var textView: NSTextView?

    var text: String { textView?.string ?? "" }

    func insert(_ snippet: String) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        if textView.shouldChangeText(in: textView.selectedRange(), replacementString: snippet) {
            textView.insertText(snippet, replacementRange: textView.selectedRange())
            textView.didChangeText()
        }
    }

    func setText(_ value: String) {
        guard let textView, textView.string != value else { return }
        textView.string = value
        textView.didChangeText()
    }
}

/// Editor de texto plano sobre NSTextView: rápido con documentos largos y
/// con notificación de cambios amortiguada para no redibujar SwiftUI.
struct CodeTextView: NSViewRepresentable {
    let initialText: String
    var font: NSFont
    var controller: EditorController?
    var padding: CGFloat = 16
    var lineHeight: CGFloat = 1.35
    var onChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.string = initialText
        textView.font = font
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: padding, height: padding)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeight
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [.font: font, .paragraphStyle: paragraph, .foregroundColor: NSColor.labelColor]
        textView.textStorage?.addAttributes([.paragraphStyle: paragraph], range: NSRange(location: 0, length: textView.string.count))

        controller?.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
        guard let textView = scroll.documentView as? NSTextView else { return }
        if controller?.textView !== textView { controller?.textView = textView }
        if textView.font != font { textView.font = font }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: (String) -> Void
        private var work: DispatchWorkItem?

        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let value = textView.string
            work?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.onChange(value) }
            work = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: item)
        }
    }
}
