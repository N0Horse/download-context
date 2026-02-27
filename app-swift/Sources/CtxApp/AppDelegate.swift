import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct ResultField {
        let label: String
        let value: String
    }

    private struct ResultSection {
        let title: String
        let fields: [ResultField]
    }

    private var statusItem: NSStatusItem!
    private let bridge = CoreBridge()

    private let downloadsKey = "settings.downloads_dir"
    private let withinKey = "settings.within_seconds"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar apps do not need window tabbing; disabling it avoids
        // AppKit tab-index warnings in package-run/dev mode.
        NSWindow.allowsAutomaticWindowTabbing = false

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
            let record = payload.capture
            var fields = [
                ResultField(label: "File Name", value: record.fileName),
                ResultField(label: "File Path", value: record.filePathAtCapture),
                ResultField(label: "Source Tab", value: record.originTitle),
                ResultField(label: "Source URL", value: record.originURL)
            ]
            if let savedNote = record.note, !savedNote.isEmpty {
                fields.append(ResultField(label: "Note", value: savedNote))
            }
            showStructuredInfo(
                "Capture Saved",
                summary: "Context linked to the latest downloaded file.",
                sections: [ResultSection(title: "Saved Record", fields: fields)]
            )
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
            var fields = [
                ResultField(label: "File Name", value: first.fileName),
                ResultField(label: "File Path", value: first.filePathAtCapture),
                ResultField(label: "Source Tab", value: first.originTitle),
                ResultField(label: "Source URL", value: first.originURL)
            ]
            if let savedNote = first.note, !savedNote.isEmpty {
                fields.append(ResultField(label: "Note", value: savedNote))
            }

            let summary: String
            if payload.count > 1 {
                summary = "\(payload.count) records found. Showing the latest match."
            } else {
                summary = "1 record found."
            }

            showStructuredInfo(
                "Lookup Result",
                summary: summary,
                sections: [ResultSection(title: "Latest Record", fields: fields)]
            )
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

            let sections = payload.results.prefix(10).enumerated().map { idx, record in
                var fields = [
                    ResultField(label: "File Name", value: record.fileName),
                    ResultField(label: "File Path", value: record.filePathAtCapture),
                    ResultField(label: "Source Tab", value: record.originTitle),
                    ResultField(label: "Source URL", value: record.originURL)
                ]
                if let savedNote = record.note, !savedNote.isEmpty {
                    fields.append(ResultField(label: "Note", value: savedNote))
                }
                return ResultSection(title: "Result \(idx + 1)", fields: fields)
            }
            showStructuredInfo(
                "Search Results",
                summary: "Showing \(min(payload.count, 10)) of \(payload.count) result(s)",
                sections: sections
            )
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
        alert.icon = nil
        alert.messageText = title
        alert.accessoryView = makeReadableMessageView(message)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showError(_ code: String, _ message: String) {
        let alert = NSAlert()
        alert.icon = nil
        alert.alertStyle = .warning
        alert.messageText = "Error [\(code)]"
        alert.accessoryView = makeReadableMessageView(message)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func makeReadableMessageView(_ message: String) -> NSView {
        let width: CGFloat = 520
        let height: CGFloat = 240

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = false

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = message

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            container.lineBreakMode = .byWordWrapping
        }

        scroll.documentView = textView
        return scroll
    }

    private func showStructuredInfo(_ title: String, summary: String, sections: [ResultSection]) {
        let alert = NSAlert()
        alert.icon = nil
        alert.messageText = title
        alert.accessoryView = makeStructuredMessageView(summary: summary, sections: sections)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func makeStructuredMessageView(summary: String, sections: [ResultSection]) -> NSView {
        let width: CGFloat = 700
        let height: CGFloat = 420

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 14, height: 14)

        let body = NSMutableAttributedString()

        let summaryStyle = NSMutableParagraphStyle()
        summaryStyle.lineBreakMode = .byWordWrapping
        summaryStyle.paragraphSpacing = 14
        body.append(
            NSAttributedString(
                string: summary + "\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: summaryStyle
                ]
            )
        )

        for section in sections {
            let sectionTitleStyle = NSMutableParagraphStyle()
            sectionTitleStyle.paragraphSpacing = 10
            body.append(
                NSAttributedString(
                    string: section.title + "\n",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: sectionTitleStyle
                    ]
                )
            )

            for field in section.fields where !field.value.isEmpty {
                let fieldLabelStyle = NSMutableParagraphStyle()
                fieldLabelStyle.paragraphSpacing = 2
                body.append(
                    NSAttributedString(
                        string: field.label.uppercased() + "\n",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .paragraphStyle: fieldLabelStyle
                        ]
                    )
                )

                let valueStyle = NSMutableParagraphStyle()
                valueStyle.lineBreakMode = .byCharWrapping
                valueStyle.paragraphSpacing = 10
                body.append(
                    NSAttributedString(
                        string: field.value + "\n",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 14),
                            .foregroundColor: NSColor.labelColor,
                            .paragraphStyle: valueStyle
                        ]
                    )
                )
            }

            body.append(
                NSAttributedString(
                    string: "────────────────────────────────────────\n\n",
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: NSColor.separatorColor
                    ]
                )
            )
        }

        textView.textStorage?.setAttributedString(body)

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: width - 28, height: CGFloat.greatestFiniteMagnitude)
            container.lineFragmentPadding = 0
            container.lineBreakMode = .byCharWrapping
        }

        scroll.documentView = textView
        return scroll
    }
}
