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
    let state = chromiumSupportDirs[app].flatMap {
        FileManager.default.contents(atPath: "\(home)/Library/Application Support/\($0)/Local State")
    }
    return lookUpProfile(profile, localState: state)
}
