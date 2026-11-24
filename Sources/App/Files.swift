import Foundation

/// Where Linkrouter reads and writes. LINKROUTER_RULES and LINKROUTER_LOG
/// point it at other files, for trying a rules file out before it goes live.

let home = FileManager.default.homeDirectoryForCurrentUser.path
let configPath = ProcessInfo.processInfo.environment["LINKROUTER_RULES"] ?? home + "/.config/linkrouter/rules"
let logPath = ProcessInfo.processInfo.environment["LINKROUTER_LOG"] ?? home + "/Library/Logs/linkrouter.log"

func log(_ line: String) {
    appendLog(line, to: logPath)
}

/// The rules file is read on every link, so an edit counts immediately.
func loadRules() -> [Rule] {
    guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
    let (rules, skipped) = parseRules(text, home: home)
    for line in skipped { log("rules: skipped line without a gap of two spaces or a tab: \(line)") }
    return rules
}

func lookUpProfile(app: String, profile: String) -> ProfileLookup {
    guard let support = chromiumSupportDirs[app] else { return .unreadable }
    let base = "\(home)/Library/Application Support/\(support)/"
    return lookUpProfile(profile, localState: FileManager.default.contents(atPath: base + "Local State")) { dir in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: base + dir, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
