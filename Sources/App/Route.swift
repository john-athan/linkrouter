import AppKit
import ApplicationServices

/// Folder of the focused window of the frontmost app, if it names one.
///
/// The folder is the Accessibility attribute AXDocument of that window
/// (ADR 0001). Ghostty fills it from the shell's working directory (OSC 7),
/// and it stays there while a program like Claude Code changes the title.
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

func open(_ urls: [URL], with target: Target, profileDirectory dir: String?) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = openArguments(urls, target: target, profileDirectory: dir)
    do { try p.run() } catch { log("open failed: \(error)") }
}

/// Asks whether to open the links in the app's last used profile, which may be
/// the wrong account. Nothing opens without that yes (ADR 0004).
func confirmWithoutProfile(_ problem: String, app: String, urls: [URL]) -> Bool {
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Linkrouter cannot find the profile"
    alert.informativeText = "\(problem).\n\nFix the rule in \(configPath).\n\nLink: \(urls.map(redact).joined(separator: " "))"
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Open in \(app) anyway")
    return alert.runModal() == .alertSecondButtonReturn
}

func route(_ urls: [URL]) {
    let (app, folder) = frontFolder()
    let target = choose(loadRules(), folder: folder)?.target ?? Target(app: "Safari")
    log("\(app) \(folder ?? "-") -> \(describe(target)) \(urls.map(redact).joined(separator: " "))")
    guard let profile = target.profile else { return open(urls, with: target, profileDirectory: nil) }
    let lookup = lookUpProfile(app: target.app, profile: profile)
    if case .directory(let dir) = lookup { return open(urls, with: target, profileDirectory: dir) }
    let problem = describe(lookup, profile: profile, app: target.app)
    log(problem)
    if confirmWithoutProfile(problem, app: target.app, urls: urls) {
        log("opened in \(target.app) without a profile, as asked")
        open(urls, with: Target(app: target.app), profileDirectory: nil)
    }
}

/// No window, no Dock icon, nothing resident (ADR 0003): macOS starts it for a
/// link, and it quits a few seconds after the last one.
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

    func quitWhenIdle() {
        idle?.invalidate()
        idle = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in NSApp.terminate(nil) }
    }
}
