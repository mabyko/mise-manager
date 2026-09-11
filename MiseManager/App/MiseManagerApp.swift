import MiseCore
import SwiftUI

@main
struct MiseManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Mise Manager", id: "main") {
            MainWindow(state: delegate.state)
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 1200, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
