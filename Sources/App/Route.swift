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

func open(_ urls: [URL], with target: Target) {
    let dir = target.profile.map { profileDirectory(app: target.app, profile: $0) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = openArguments(urls, target: target, profileDirectory: dir)
    do { try p.run() } catch { log("open failed: \(error)") }
}

func route(_ urls: [URL]) {
    let (app, folder) = frontFolder()
    let target = choose(loadRules(), folder: folder)?.target ?? Target(app: "Safari")
    log("\(app) \(folder ?? "-") -> \(describe(target)) \(urls.map(redact).joined(separator: " "))")
    open(urls, with: target)
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
