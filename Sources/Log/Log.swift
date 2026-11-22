import Foundation

/// The one file Linkrouter writes, and what it keeps out of it (ADR 0005).
///
/// A line per link says which app and folder it came from and which browser
/// it went to, so a surprising choice can be explained. It names the link by
/// its host only. A full URL carries whatever the sender put in it: sign-in
/// codes, reset tokens, magic links, search terms. None of that is needed to
/// explain a choice that depends on the folder and never on the link, and a
/// plain-text file of it would be a history nobody asked to keep.
///
/// The file is also bounded: past `logLimit` bytes the older half goes. And it
/// is this user's alone (0600). A log that is not was written by 1.0.0, which
/// kept whole URLs and set no mode, so it is started over rather than kept.

let logLimit = 256 * 1024

/// How the log names a link: `https://github.com`, or `mailto` for a link
/// without a host.
func redact(_ url: URL) -> String {
    guard let scheme = url.scheme else { return "?" }
    guard let host = url.host, !host.isEmpty else { return scheme }
    return "\(scheme)://\(host)"
}

/// `data` cut to its newest half when it is over `limit`, starting at a line,
/// so a trimmed log never begins mid-line. Unchanged when within the limit.
func trimmed(_ data: Data, limit: Int) -> Data {
    guard data.count > limit else { return data }
    let tail = data.suffix(limit / 2)
    guard let newline = tail.firstIndex(of: UInt8(ascii: "\n")) else { return Data() }
    return Data(tail[tail.index(after: newline)...])
}

func appendLog(_ line: String, to path: String, now: Date = Date()) {
    let stamp = ISO8601DateFormatter().string(from: now)
    let entry = Data("\(stamp) \(line)\n".utf8)
    let fm = FileManager.default
    let mode = (try? fm.attributesOfItem(atPath: path)[.posixPermissions]) as? Int
    let old = mode == 0o600 ? fm.contents(atPath: path) ?? Data() : Data()
    if mode == 0o600, old.count + entry.count <= logLimit,
       let h = FileHandle(forWritingAtPath: path) {
        h.seekToEndOfFile()
        h.write(entry)
        try? h.close()
        return
    }
    // New, old, or over the limit: write it whole, readable by this user only.
    // createFile applies the mode only to a file it creates, so it is set after.
    fm.createFile(atPath: path, contents: trimmed(old + entry, limit: logLimit),
                  attributes: [.posixPermissions: 0o600])
    try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
}
