import Foundation

/// The rules file and the choice it makes. Nothing in here touches AppKit, the
/// Accessibility interface or the disk, so all of it is tested directly.
///
/// One rule per line: a folder, two spaces or a tab, then an app and, after a
/// colon, an optional profile. `*` as the folder is the fallback. The most
/// specific folder that contains the clicked window's folder wins, so the order
/// of the lines does not matter (ADR 0002).

struct Target: Equatable {
    var app: String
    var profile: String?
}

struct Rule: Equatable {
    var folder: String  // absolute, no trailing slash; "*" is the fallback
    var target: Target
}

/// The rules in `text`, and every line that was not a rule, so the caller can
/// say which line it ignored rather than ignore it quietly.
func parseRules(_ text: String, home: String) -> (rules: [Rule], skipped: [String]) {
    var rules: [Rule] = []
    var skipped: [String] = []
    for raw in text.split(separator: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        guard let gap = line.range(of: #"\s{2,}|\t"#, options: .regularExpression) else {
            skipped.append(line)
            continue
        }
        var folder = String(line[..<gap.lowerBound])
        let rest = line[gap.upperBound...].trimmingCharacters(in: .whitespaces)
        if folder.hasPrefix("~") { folder = home + folder.dropFirst() }
        while folder.count > 1 && folder.hasSuffix("/") { folder.removeLast() }
        let parts = rest.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        rules.append(Rule(folder: folder, target: Target(app: parts[0], profile: parts.count > 1 ? parts[1] : nil)))
    }
    return (rules, skipped)
}

/// The rule whose folder contains `folder` most specifically; otherwise `*`.
/// A folder contains itself and what lies below it, so `~/work` does not
/// contain `~/workshop`.
func choose(_ rules: [Rule], folder: String?) -> Rule? {
    if let folder {
        let hit = rules
            .filter { $0.folder != "*" && (folder == $0.folder || folder.hasPrefix($0.folder + "/")) }
            .max { $0.folder.count < $1.folder.count }
        if let hit { return hit }
    }
    return rules.first { $0.folder == "*" }
}

/// How `--which` and the log name a rule: `~/work -> Google Chrome: Work`.
func describe(_ rule: Rule) -> String {
    "\(rule.folder) -> \(describe(rule.target))"
}

func describe(_ target: Target) -> String {
    target.app + (target.profile.map { ": \($0)" } ?? "")
}

/// Where each Chromium browser keeps its `Local State`, under
/// ~/Library/Application Support. Profiles work for these and no others.
let chromiumSupportDirs: [String: String] = [
    "Google Chrome": "Google/Chrome",
    "Google Chrome Beta": "Google/Chrome Beta",
    "Brave Browser": "BraveSoftware/Brave-Browser",
    "Chromium": "Chromium",
]

/// The profile directory Chrome needs (`Profile 2`) for what the rule says,
/// which may be that directory or the name Chrome shows (`Work`). The names
/// are in `Local State` under `profile.info_cache` (ADR 0004). Anything this
/// cannot resolve is passed through unchanged, so Chrome reports the problem
/// rather than this guessing.
func profileDirectory(profile: String, localState: Data?) -> String {
    guard let localState,
          let json = try? JSONSerialization.jsonObject(with: localState) as? [String: Any],
          let cache = (json["profile"] as? [String: Any])?["info_cache"] as? [String: Any]
    else { return profile }
    if cache[profile] != nil { return profile }
    // Sorted, so two profiles with one name resolve the same way every time.
    for dir in cache.keys.sorted() where (cache[dir] as? [String: Any])?["name"] as? String == profile {
        return dir
    }
    return profile
}

/// The arguments for /usr/bin/open. Passed as a list and never through a
/// shell, so nothing in a URL or a rule can become a command.
func openArguments(_ urls: [URL], target: Target, profileDirectory dir: String?) -> [String] {
    if let dir {
        // -n starts a short-lived instance that hands the URL to the running
        // browser, in the given profile.
        return ["-na", target.app, "--args", "--profile-directory=\(dir)"] + urls.map(\.absoluteString)
    }
    return ["-a", target.app] + urls.map(\.absoluteString)
}
