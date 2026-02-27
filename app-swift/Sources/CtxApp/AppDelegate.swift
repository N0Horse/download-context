import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let bridge = CoreBridge()

    private let downloadsKey = "settings.downloads_dir"
    private let withinKey = "settings.within_seconds"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Ctx"
        statusItem.menu = buildMenu()

        if UserDefaults.standard.string(forKey: downloadsKey) == nil {
            UserDefaults.standard.set("~/Downloads", forKey: downloadsKey)
        }
        if UserDefaults.standard.object(forKey: withinKey) == nil {
            UserDefaults.standard.set(60, forKey: withinKey)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Latest Download...", action: #selector(capture), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Lookup File...", action: #selector(lookup), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Search...", action: #selector(search), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(settings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }

    @objc private func capture() {
        do {
            let safari = try SafariContextProvider.activeTab()
            let note = promptForOptionalNote(defaultText: "")
            let downloadsDir = (UserDefaults.standard.string(forKey: downloadsKey) ?? "~/Downloads")
            let within = UserDefaults.standard.integer(forKey: withinKey)
            let payload = try bridge.runCapture(
                downloadsDir: downloadsDir,
                within: max(1, within),
                originTitle: safari.title,
                originURL: safari.url,
                note: note
            )
            showInfo("Capture Saved", "Linked \(payload.capture.fileName) -> \(payload.capture.originTitle)")
        } catch let e as CoreError {
            showError(e.code, e.message)
        } catch {
            showError("UNKNOWN_ERROR", error.localizedDescription)
        }
    }

    @objc private func lookup() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Lookup"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let payload = try bridge.runLookup(path: url.path)
            if payload.records.isEmpty {
                showInfo("Lookup", "No context saved for this file.")
                return
            }

            let first = payload.records[0]
            var body = "\(first.originTitle)\n\(first.originURL)\n"
            if let note = first.note, !note.isEmpty {
                body += "\nNote: \(note)\n"
            }
            if payload.count > 1 {
                body += "\n\(payload.count) records found (showing latest)."
            }
            showInfo("Lookup Result", body)
        } catch let e as CoreError {
            showError(e.code, e.message)
        } catch {
            showError("UNKNOWN_ERROR", error.localizedDescription)
        }
    }

    @objc private func search() {
        guard let query = promptForRequiredText(title: "Search", message: "Enter keywords (empty shows recent):", defaultText: "") else {
            return
        }

        do {
            let payload = try bridge.runSearch(query: query)
            if payload.results.isEmpty {
                showInfo("Search", "No results.")
                return
            }

            let lines = payload.results.prefix(10).map { "- \($0.fileName): \($0.originTitle)" }
            let summary = lines.joined(separator: "\n")
            showInfo("Search Results", "Backend: \(payload.backend)\n\n\(summary)")
        } catch let e as CoreError {
            showError(e.code, e.message)
        } catch {
            showError("UNKNOWN_ERROR", error.localizedDescription)
        }
    }

    @objc private func settings() {
        let defaults = UserDefaults.standard
        let currentDir = defaults.string(forKey: downloadsKey) ?? "~/Downloads"
        let currentWithin = defaults.integer(forKey: withinKey)

        let form = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 76))

        let dirField = NSTextField(frame: NSRect(x: 0, y: 40, width: 360, height: 24))
        dirField.placeholderString = "Downloads directory"
        dirField.stringValue = currentDir

        let withinField = NSTextField(frame: NSRect(x: 0, y: 8, width: 120, height: 24))
        withinField.placeholderString = "Within seconds"
        withinField.stringValue = "\(currentWithin <= 0 ? 60 : currentWithin)"

        form.addSubview(dirField)
        form.addSubview(withinField)

        let alert = NSAlert()
        alert.messageText = "Settings"
        alert.informativeText = "Configure default downloads directory and capture window."
        alert.accessoryView = form
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let trimmedDir = dirField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDir.isEmpty {
            defaults.set(trimmedDir, forKey: downloadsKey)
        }

        let within = Int(withinField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 60
        defaults.set(max(1, within), forKey: withinKey)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func promptForOptionalNote(defaultText: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Capture Note"
        alert.informativeText = "Optional note for why you downloaded this file."

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = defaultText
        alert.accessoryView = field

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() != .alertFirstButtonReturn {
            return nil
        }

        let note = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : note
    }

    private func promptForRequiredText(title: String, message: String, defaultText: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = defaultText
        alert.accessoryView = field

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showInfo(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func showError(_ code: String, _ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Error [\(code)]"
        alert.informativeText = message
        alert.runModal()
    }
}
