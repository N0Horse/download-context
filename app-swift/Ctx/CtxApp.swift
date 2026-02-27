import AppKit

@main
final class CtxApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Ctx"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Latest Download...", action: #selector(capture), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Lookup File...", action: #selector(lookup), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Search...", action: #selector(search), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func capture() {
        // UI dialog wiring intentionally left for app target integration.
    }

    @objc private func lookup() {
        // UI dialog wiring intentionally left for app target integration.
    }

    @objc private func search() {
        // UI dialog wiring intentionally left for app target integration.
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
