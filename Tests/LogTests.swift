import Foundation

/// The log names a link by its host, and stays small (ADR 0005).
func runLogTests() {
    Check.suite("a link is logged by its host") {
        Check.equal(redact(URL(string: "https://accounts.example.com/reset?token=s3cr3t")!),
                    "https://accounts.example.com", "path and query stay out")
        Check.equal(redact(URL(string: "http://user:pw@example.com:8080/x")!), "http://example.com",
                    "credentials and port stay out")
        Check.equal(redact(URL(string: "file:///Users/test/page.html")!), "file", "a file is named by its scheme")
    }

    Check.suite("the log is bounded") {
        let small = Data("a\nb\n".utf8)
        Check.equal(trimmed(small, limit: 100), small, "within the limit: unchanged")
        let lines = (0..<100).map { "line \($0)\n" }.joined()
        let cut = trimmed(Data(lines.utf8), limit: 200)
        Check.that(cut.count <= 100, "over the limit: at most half of it is kept")
        let text = String(decoding: cut, as: UTF8.self)
        Check.that(text.hasPrefix("line "), "and it starts at a line")
        Check.that(text.hasSuffix("line 99\n"), "the newest lines are the ones kept")
    }

    Check.suite("writing") {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("linkrouter-log-\(getpid())")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("log").path
        appendLog("one", to: path)
        appendLog("two", to: path)
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        Check.equal(text.split(separator: "\n").map { $0.split(separator: " ").last.map(String.init) ?? "" },
                    ["one", "two"], "lines are appended in order")
        let mode = (try? FileManager.default.attributesOfItem(atPath: path)[.posixPermissions]) as? Int
        Check.equal(mode, 0o600, "readable by this user only")
        let old = dir.appendingPathComponent("old").path
        FileManager.default.createFile(atPath: old, contents: Data("1.0.0 https://x.example/?token=t\n".utf8),
                                       attributes: [.posixPermissions: 0o644])
        appendLog("new", to: old)
        let after = (try? String(contentsOfFile: old, encoding: .utf8)) ?? ""
        Check.that(!after.contains("token"), "a log 1.0.0 wrote is started over, whole URLs and all")
        Check.equal((try? FileManager.default.attributesOfItem(atPath: old)[.posixPermissions]) as? Int, 0o600,
                    "and is this user's alone afterwards")
        for i in 0..<5000 { appendLog("entry \(i) " + String(repeating: "x", count: 60), to: path) }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int ?? 0
        Check.that(size <= logLimit, "five thousand lines later it is still within the limit")
    }
}
