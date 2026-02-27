import Foundation

final class CoreBridge {
    private let decoder = JSONDecoder()
    private let compileTimeSourcePath = #filePath

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
        guard let payload = envelope.data else {
            throw CoreError(code: "BAD_RESPONSE", message: "Missing payload")
        }
        return payload
    }

    func runLookup(path: String) throws -> LookupPayload {
        let data = try runRaw(args: ["lookup", "--path", path])
        let envelope = try decoder.decode(CoreEnvelope<LookupPayload>.self, from: data)
        if let error = envelope.error { throw error }
        guard let payload = envelope.data else {
            throw CoreError(code: "BAD_RESPONSE", message: "Missing payload")
        }
        return payload
    }

    func runSearch(query: String, limit: Int = 20) throws -> SearchPayload {
        let data = try runRaw(args: ["search", "--q", query, "--limit", "\(limit)"])
        let envelope = try decoder.decode(CoreEnvelope<SearchPayload>.self, from: data)
        if let error = envelope.error { throw error }
        guard let payload = envelope.data else {
            throw CoreError(code: "BAD_RESPONSE", message: "Missing payload")
        }
        return payload
    }

    private func runRaw(args: [String]) throws -> Data {
        let process = Process()

        if let coreExec = resolveBundledCorePath() {
            process.executableURL = coreExec
            process.arguments = args
        } else {
            guard let corePythonPath = resolveCorePythonPath() else {
                throw CoreError(
                    code: "CORE_NOT_FOUND",
                    message: "Could not find ctx-core or core-python. Build the app bundle with ./scripts/build_app.sh, or set CTX_CORE_PATH (binary) / CTX_CORE_PYTHON_PATH (source)."
                )
            }
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", "-m", "ctx_core"] + args
            process.environment = mergedPythonEnv(corePythonPath: corePythonPath)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        if outputData.isEmpty {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            throw CoreError(code: "EMPTY_OUTPUT", message: "ctx-core returned no output: \(errText)")
        }
        return outputData
    }

    private func resolveBundledCorePath() -> URL? {
        if let explicit = ProcessInfo.processInfo.environment["CTX_CORE_PATH"], !explicit.isEmpty {
            let url = URL(fileURLWithPath: explicit)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        let bundled = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("ctx-core")
        if let bundled, FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        return nil
    }

    private func resolveCorePythonPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["CTX_CORE_PYTHON_PATH"], !explicit.isEmpty {
            let expanded = NSString(string: explicit).expandingTildeInPath
            let candidate = URL(fileURLWithPath: expanded).path
            let marker = URL(fileURLWithPath: candidate).appendingPathComponent("ctx_core/__init__.py").path
            if FileManager.default.fileExists(atPath: marker) {
                return candidate
            }
        }

        var candidates: [String] = []
        let cwd = FileManager.default.currentDirectoryPath
        candidates.append(cwd)
        candidates.append((cwd as NSString).deletingLastPathComponent)
        candidates.append(((cwd as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)

        if let execDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            candidates.append(execDir)
            candidates.append((execDir as NSString).deletingLastPathComponent)
            candidates.append(((execDir as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)
        }

        if let repoRoot = env["CTX_REPO_ROOT"], !repoRoot.isEmpty {
            candidates.append(NSString(string: repoRoot).expandingTildeInPath)
        }

        // Xcode/SwiftPM local-dev fallback: derive repo root from this source file path.
        // Example:
        //   .../download-context/app-swift/Sources/CtxApp/CoreBridge.swift
        // -> .../download-context
        let sourceURL = URL(fileURLWithPath: compileTimeSourcePath)
        let possibleRepoRoot = sourceURL
            .deletingLastPathComponent() // CtxApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // app-swift
            .deletingLastPathComponent() // repo root
            .path
        candidates.append(possibleRepoRoot)

        for base in candidates {
            let corePython = URL(fileURLWithPath: base).appendingPathComponent("core-python")
            let marker = corePython.appendingPathComponent("ctx_core/__init__.py").path
            if FileManager.default.fileExists(atPath: marker) {
                return corePython.path
            }
        }

        return nil
    }

    private func mergedPythonEnv(corePythonPath: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let existing = env["PYTHONPATH"], !existing.isEmpty {
            env["PYTHONPATH"] = corePythonPath + ":" + existing
        } else {
            env["PYTHONPATH"] = corePythonPath
        }
        return env
    }
}
