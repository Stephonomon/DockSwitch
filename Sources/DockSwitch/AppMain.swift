import AppKit

@main
struct DockSwitchAppMain {
    // NSApplication.delegate is weak; keep a strong reference for the app's
    // lifetime so the delegate isn't deallocated before launch completes.
    @MainActor private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        menuBarController = MenuBarController(state: state)
    }
}
