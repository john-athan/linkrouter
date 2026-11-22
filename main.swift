// linkrouter: a default browser that forwards each link to a real browser,
// chosen by the folder of the window you clicked in.
//
// The folder comes from the Accessibility attribute AXDocument of the
// frontmost app's focused window. Ghostty fills it from the shell's working
// directory (OSC 7), and it stays there while a program like Claude Code
// changes the window title.

import AppKit
import ApplicationServices

let home = FileManager.default.homeDirectoryForCurrentUser.path
// LINKROUTER_RULES points at another rules file; the tests use it.
let configPath = ProcessInfo.processInfo.environment["LINKROUTER_RULES"] ?? home + "/.config/linkrouter/rules"
let logPath = ProcessInfo.processInfo.environment["LINKROUTER_LOG"] ?? home + "/Library/Logs/linkrouter.log"

struct Target {
    var app: String
    var profile: String?
}

struct Rule {
    var folder: String  // absolute, no trailing slash; "*" is the fallback
    var target: Target
}

func log(_ line: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    let data = Data("\(stamp) \(line)\n".utf8)
    if let h = FileHandle(forWritingAtPath: logPath) {
        h.seekToEndOfFile()
        h.write(data)
        try? h.close()
    } else {
        FileManager.default.createFile(atPath: logPath, contents: data)
    }
}

/// Rules file: one rule per line, `folder  App Name: Profile`.
/// The profile is optional and may be Chrome's display name ("Work") or its
/// directory ("Profile 2"). `*` as the folder is the fallback.
func loadRules() -> [Rule] {
    guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
    var rules: [Rule] = []
    for raw in text.split(separator: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        guard let gap = line.range(of: #"\s{2,}|\t"#, options: .regularExpression) else {
            log("rules: skipped line without a gap of two spaces or a tab: \(line)")
            continue
        }
        var folder = String(line[..<gap.lowerBound])
        let rest = line[gap.upperBound...].trimmingCharacters(in: .whitespaces)
        if folder.hasPrefix("~") { folder = home + folder.dropFirst() }
        while folder.count > 1 && folder.hasSuffix("/") { folder.removeLast() }
        let parts = rest.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        rules.append(Rule(folder: folder, target: Target(app: parts[0], profile: parts.count > 1 ? parts[1] : nil)))
    }
    return rules
}

/// The rule whose folder contains `folder` most specifically; otherwise `*`.
func choose(_ rules: [Rule], folder: String?) -> Rule? {
    if let folder {
        let hit = rules
            .filter { $0.folder != "*" && (folder == $0.folder || folder.hasPrefix($0.folder + "/")) }
            .max { $0.folder.count < $1.folder.count }
        if let hit { return hit }
    }
    return rules.first { $0.folder == "*" }
}

/// Folder of the focused window of the frontmost app, if it exposes one.
func frontFolder() -> (app: String, folder: String?) {
    guard let front = NSWorkspace.shared.frontmostApplication else { return ("?", nil) }
    let name = front.bundleIdentifier ?? front.localizedName ?? "?"
    let ax = AXUIElementCreateApplication(front.processIdentifier)
    var window: CFTypeRef?
    guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &window) == .success,
          let window else { return (name, nil) }
    var doc: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXDocumentAttribute as CFString, &doc) == .success,
          let s = doc as? String, let url = URL(string: s), url.isFileURL else { return (name, nil) }
    var path = url.path
    while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
    return (name, path)
}

/// Chrome-family profile: accept the display name and map it to the directory.
func profileDirectory(app: String, profile: String) -> String {
    let dirs = [
        "Google Chrome": "Google/Chrome",
        "Google Chrome Beta": "Google/Chrome Beta",
        "Brave Browser": "BraveSoftware/Brave-Browser",
        "Chromium": "Chromium",
    ]
    guard let sub = dirs[app],
          let data = FileManager.default.contents(atPath: "\(home)/Library/Application Support/\(sub)/Local State"),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let cache = (json["profile"] as? [String: Any])?["info_cache"] as? [String: Any]
    else { return profile }
    if cache[profile] != nil { return profile }
    for (dir, info) in cache where (info as? [String: Any])?["name"] as? String == profile { return dir }
    return profile
}

func open(_ urls: [URL], with target: Target) {
    var args: [String]
    if let profile = target.profile {
        // -n starts a short-lived instance that hands the URL to the running
        // browser, in the given profile.
        args = ["-na", target.app, "--args", "--profile-directory=\(profileDirectory(app: target.app, profile: profile))"]
        args += urls.map(\.absoluteString)
    } else {
        args = ["-a", target.app] + urls.map(\.absoluteString)
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = args
    do { try p.run() } catch { log("open failed: \(error)") }
}

func route(_ urls: [URL]) {
    let (app, folder) = frontFolder()
    let rules = loadRules()
    let target = choose(rules, folder: folder)?.target ?? Target(app: "Safari")
    log("\(app) \(folder ?? "-") -> \(target.app)\(target.profile.map { ": \($0)" } ?? "") \(urls.map(\.absoluteString).joined(separator: " "))")
    open(urls, with: target)
}

final class Delegate: NSObject, NSApplicationDelegate {
    var idle: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            log("no Accessibility permission yet: every link goes to the * rule")
        }
        quitWhenIdle()
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        route(urls)
        quitWhenIdle()
    }

    // Nothing stays resident: quit a few seconds after the last link.
    func quitWhenIdle() {
        idle?.invalidate()
        idle = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in NSApp.terminate(nil) }
    }
}

let argv = CommandLine.arguments
if argv.count >= 2 && argv[1] == "--which" {
    // Dry run: linkrouter --which <folder>  prints the rule that would win.
    let folder = argv.count >= 3 ? argv[2] : nil
    let rule = choose(loadRules(), folder: folder)
    print(rule.map { "\($0.folder) -> \($0.target.app)\($0.target.profile.map { ": \($0)" } ?? "")" } ?? "no rule")
    if let p = rule?.target.profile { print("profile directory: \(profileDirectory(app: rule!.target.app, profile: p))") }
    exit(0)
}
if argv.count >= 2 && argv[1] == "--set-default" {
    let me = Bundle.main.bundleURL
    let group = DispatchGroup()
    for scheme in ["http", "https"] {
        group.enter()
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: scheme) { err in
            print("\(scheme): \(err.map { "\($0)" } ?? "ok")")
            group.leave()
        }
    }
    while group.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    exit(0)
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.prohibited)
NSApplication.shared.run()
