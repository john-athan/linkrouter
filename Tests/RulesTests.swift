import Foundation

/// The rules: parsing, the choice, and the arguments a choice turns into.
///
/// These are the cases validate.sh used to check through `--which`, now
/// against the functions themselves, plus the profile lookup it could not
/// reach without a Chrome on the machine.
func runRulesTests() {
    let home = "/Users/test"
    let text = """
    # comment
    ~/work                 Google Chrome: Work
    ~/work/clients/acme/   Google Chrome: Profile 3
    /srv\tFirefox
    /opt one space Safari
    *                      Brave Browser
    """
    let (rules, skipped) = parseRules(text, home: home)

    Check.suite("parsing") {
        Check.equal(rules.count, 4, "four rules, the comment and the one-space line left out")
        Check.equal(skipped, ["/opt one space Safari"], "the one-space line is reported, not dropped quietly")
        Check.equal(rules.first, Rule(folder: "/Users/test/work", target: Target(app: "Google Chrome", profile: "Work")),
                    "~ is the home folder, and the profile follows the colon")
        Check.equal(rules[1].folder, "/Users/test/work/clients/acme", "a trailing slash is dropped")
        Check.equal(rules[2].target, Target(app: "Firefox"), "a tab is a gap, and no colon is no profile")
        Check.equal(parseRules("", home: home).rules, [], "an empty file is no rules")
        let crlf = parseRules("/a  Google Chrome: Work\r\n/b  Safari\r\n", home: home)
        Check.equal(crlf.rules.first?.target.profile, "Work", "a CRLF file leaves no carriage return in the profile")
        let noApp = parseRules("/a  : Work\n/b  :\n/c  Safari:\n", home: home)
        Check.equal(noApp.skipped, ["/a  : Work", "/b  :"], "a rule without an app is reported, not a crash")
        Check.equal(noApp.rules.first?.target, Target(app: "Safari"), "an empty profile after the colon is no profile")
    }

    Check.suite("the most specific folder wins") {
        func which(_ folder: String?) -> String { choose(rules, folder: folder).map(describe) ?? "no rule" }
        let w = "\(home)/work"
        Check.equal(which(w), "\(w) -> Google Chrome: Work", "the folder itself")
        Check.equal(which("\(w)/platform/app"), "\(w) -> Google Chrome: Work", "below it")
        Check.equal(which("\(w)/clients/acme"), "\(w)/clients/acme -> Google Chrome: Profile 3", "a deeper rule")
        Check.equal(which("\(w)/clients/acme/code"), "\(w)/clients/acme -> Google Chrome: Profile 3", "below the deeper rule")
        Check.equal(which("\(w)/clients/acmex"), "\(w) -> Google Chrome: Work", "a longer name is not a subfolder")
        Check.equal(which("\(home)/workshop"), "* -> Brave Browser", "nor is a name that starts the same")
        Check.equal(which("/srv/x"), "/srv -> Firefox", "a tab-separated rule")
        Check.equal(which("/opt/x"), "* -> Brave Browser", "a skipped line routes nothing")
        Check.equal(which(nil), "* -> Brave Browser", "no folder gets the fallback")
        Check.isNil(choose([], folder: w), "no rules, no choice")
        let tie = parseRules("~/work  Safari\n~/work  Firefox\n", home: home).rules
        Check.equal(choose(tie, folder: w)?.target.app, "Safari", "two rules for one folder: the first wins")
        let reordered = Array(rules.reversed())
        Check.equal(choose(reordered, folder: "\(w)/clients/acme")?.target.profile, "Profile 3", "order does not matter")
    }

    Check.suite("rules.example") {
        guard let example = Check.unwrap(try? String(contentsOfFile: "rules.example", encoding: .utf8),
                                         "rules.example is readable") else { return }
        let parsed = parseRules(example, home: home)
        Check.equal(parsed.skipped, [], "every line of the example is a rule or a comment")
        Check.that(parsed.rules.contains { $0.folder == "*" }, "the example has a fallback")
    }

    Check.suite("profiles by the name Chrome shows") {
        let state = Data("""
        {"profile": {"info_cache": {
          "Default":   {"name": "Person 1"},
          "Profile 2": {"name": "Work"},
          "Profile 3": {"name": "Acme"}
        }}}
        """.utf8)
        Check.equal(lookUpProfile("Work", localState: state), .directory("Profile 2"), "a name becomes its directory")
        Check.equal(lookUpProfile("Profile 3", localState: state), .directory("Profile 3"), "a directory stays itself")
        Check.equal(lookUpProfile("Nobody", localState: state), .unknown(known: ["Person 1", "Work", "Acme"]),
                    "an unknown name is refused and lists the names, never passed to Chrome")
        Check.equal(lookUpProfile("Work", localState: nil), .unreadable, "no Local State is refused")
        Check.equal(lookUpProfile("Work", localState: Data("{".utf8)), .unreadable, "broken JSON is refused")

        // The bug of 1.0.1: an unresolved "Work" made Chrome create an empty
        // directory "Work", which then matched by directory on every link.
        let shadowed = Data("""
        {"profile": {"info_cache": {
          "Default": {"name": "Work"},
          "Work":    {"name": "Your Chrome"}
        }}}
        """.utf8)
        Check.equal(lookUpProfile("Work", localState: shadowed), .directory("Default"),
                    "the name Chrome shows wins over a directory of the same spelling")

        Check.equal(describe(.unknown(known: ["Work"]), profile: "Acme", app: "Google Chrome"),
                    "Google Chrome has no profile \"Acme\"; its profiles are: Work", "the refusal names the profiles")
        Check.that(describe(.unreadable, profile: "Work", app: "Safari").hasPrefix("Safari has no profiles"),
                   "a profile on a browser without profiles is refused")
    }

    Check.suite("the arguments for open") {
        let urls = [URL(string: "https://example.com/a?b=c")!]
        Check.equal(openArguments(urls, target: Target(app: "Safari"), profileDirectory: nil),
                    ["-a", "Safari", "https://example.com/a?b=c"], "no profile: hand it over")
        Check.equal(openArguments(urls, target: Target(app: "Google Chrome", profile: "Work"), profileDirectory: "Profile 2"),
                    ["-na", "Google Chrome", "--args", "--profile-directory=Profile 2", "https://example.com/a?b=c"],
                    "a profile: a new instance with the directory")
        let odd = Target(app: "Safari; rm -rf ~", profile: nil)
        Check.equal(openArguments(urls, target: odd, profileDirectory: nil)[1], "Safari; rm -rf ~",
                    "an app name is one argument, never parsed by a shell")
    }
}
