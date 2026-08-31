import AppKit
import SwiftUI

@main
struct MarkportApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = StyleStore()
    @StateObject private var state = AppState()
    @StateObject private var previews = PreviewCache()

    var body: some Scene {
        WindowGroup("Markport") {
            RootView()
                .environmentObject(store)
                .environmentObject(state)
                .environmentObject(previews)
                .frame(minWidth: 880, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Style") {
                    state.editing = DocStyle.new(name: store.uniqueName(base: "Style"))
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .saveItem) {
                Button("Preview") { state.showingPreview = true }
                    .keyboardShortcut("p")
                    .disabled(store.styles.isEmpty)
                Button("Export PDF…") { state.export(store: store) }
                    .keyboardShortcut("e")
                    .disabled(store.styles.isEmpty)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct RootView: View {
    @EnvironmentObject private var store: StyleStore
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if store.styles.isEmpty {
                OnboardingView()
            } else {
                MainView()
            }
        }
        .sheet(item: $state.editing) { style in
            StyleEditorView(style: style)
                .environmentObject(store)
                .environmentObject(state)
        }
    }
}
