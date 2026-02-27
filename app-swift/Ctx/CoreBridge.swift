import Foundation

final class CoreBridge {
    private let decoder = JSONDecoder()

    private var coreURL: URL {
        let executableDir = Bundle.main.executableURL!.deletingLastPathComponent()
        return executableDir.appendingPathComponent("ctx-core")
    }

    func runCapture(downloadsDir: String, within: Int, originTitle: String, originURL: String, note: String?) throws -> CapturePayload {
        var args = [
            "capture",
            "--downloads-dir", downloadsDir,
            "--within", "\(within)",
            "--origin-title", originTitle,
            "--origin-url", originURL,
            "--source-app", "ctx-app"
        ]
        if let note, !note.isEmpty {
            args.append(contentsOf: ["--note", note])
        }
        let data = try runRaw(args: args)
        let envelope = try decoder.decode(CoreEnvelope<CapturePayload>.self, from: data)
        if let error = envelope.error { throw error }
        guard let payload = envelope.data else { throw CoreError(code: "BAD_RESPONSE", message: "Missing payload") }
        return payload
    }

    func runLookup(path: String) throws -> LookupPayload {
        let data = try runRaw(args: ["lookup", "--path", path])
        let envelope = try decoder.decode(CoreEnvelope<LookupPayload>.self, from: data)
        if let error = envelope.error { throw error }
        guard let payload = envelope.data else { throw CoreError(code: "BAD_RESPONSE", message: "Missing payload") }
        return payload
    }

    func runSearch(query: String, limit: Int = 20) throws -> SearchPayload {
        let data = try runRaw(args: ["search", "--q", query, "--limit", "\(limit)"])
        let envelope = try decoder.decode(CoreEnvelope<SearchPayload>.self, from: data)
        if let error = envelope.error { throw error }
        guard let payload = envelope.data else { throw CoreError(code: "BAD_RESPONSE", message: "Missing payload") }
        return payload
    }

    private func runRaw(args: [String]) throws -> Data {
        let process = Process()
        process.executableURL = coreURL
        process.arguments = args

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        guard !outputData.isEmpty else {
            throw CoreError(code: "EMPTY_OUTPUT", message: "ctx-core returned no output")
        }
        return outputData
    }
}
