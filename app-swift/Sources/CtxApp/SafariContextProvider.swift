import Foundation

struct SafariContext {
    let title: String
    let url: String
}

enum SafariContextProvider {
    static func activeTab() throws -> SafariContext {
        let title = try runAppleScript("tell application \"Safari\" to return name of current tab of front window")
        let url = try runAppleScript("tell application \"Safari\" to return URL of current tab of front window")
        guard !title.isEmpty, !url.isEmpty else {
            throw CoreError(code: "SAFARI_CONTEXT_MISSING", message: "Safari not available or no active tab.")
        }
        return SafariContext(title: title, url: url)
    }

    private static func runAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            throw CoreError(code: "SAFARI_CONTEXT_MISSING", message: text.isEmpty ? "Safari not available or no active tab." : text)
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
