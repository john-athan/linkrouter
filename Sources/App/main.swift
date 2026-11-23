// linkrouter: a default browser that forwards each link to a real browser,
// chosen by the folder of the window you clicked in.

import AppKit

let usage = """
usage: linkrouter --which <folder>   print the rule a folder gets, open nothing
       linkrouter --set-default      make this copy the default browser
       linkrouter --help             this

Rules: \(configPath)
Log:   \(logPath)
"""

let argv = CommandLine.arguments
switch argv.count >= 2 ? argv[1] : nil {
case "--which":
    let folder = argv.count >= 3 ? argv[2] : nil
    guard let rule = choose(loadRules(), folder: folder) else {
        print("no rule")
        exit(0)
    }
    print(describe(rule))
    if let p = rule.target.profile {
        print(describe(lookUpProfile(app: rule.target.app, profile: p), profile: p, app: rule.target.app))
    }
    exit(0)

case "--set-default":
    let me = Bundle.main.bundleURL
    // Register this copy first, so it works wherever it was copied to.
    LSRegisterURL(me as CFURL, true)
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

case "--help", "-h", "help":
    print(usage)
    exit(0)

default:
    // Anything else, including whatever macOS passes when it starts the app
    // for a link, runs it as the browser.
    let delegate = Delegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.setActivationPolicy(.prohibited)
    NSApplication.shared.run()
}
