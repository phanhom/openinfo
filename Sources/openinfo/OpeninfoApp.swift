import SwiftUI

@main
struct OpeninfoApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Single shared view-model, owned by the App struct lifetime
    @State private var vm = GamesViewModel()

    var body: some Scene {

        // ── 1. Menu Bar Extra ────────────────────────────────────────────
        // The label Text updates dynamically as vm.menuBarTitle changes.
        MenuBarExtra {
            MenuBarPopoverView()
                .environment(vm)
        } label: {
            if !vm.hasAnyGames {
                Image(systemName: vm.selectedLeague.sfSymbol)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Text(vm.menuBarTitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)

        // ── 2. Floating Desktop Window ───────────────────────────────────
        Window("NBA Scores", id: "floating") {
            FloatingWindowView()
                .environment(vm)
        }        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
