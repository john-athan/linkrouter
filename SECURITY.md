# Security Policy

## Reporting a vulnerability

Please report security issues privately via GitHub's
[private vulnerability reporting](https://github.com/john-athan/linkrouter/security/advisories/new)
rather than opening a public issue. I'll aim to respond within a few days.

## What Linkrouter promises

Linkrouter is your default browser, so every link you click passes through it,
and it holds the Accessibility permission. Both are worth stating limits for.

- **No network.** It opens no socket. A link is handed to a browser on this
  Mac and never looked at beyond its scheme and host.
- **One Accessibility read, only when a link arrives.** It reads the focused
  window's document (`AXDocument`) of the app in front, and nothing else: no
  window contents, no keystrokes, no other app's windows. It does not run
  between links; it quits five seconds after the last one.
- **No shell.** The browser is started by `/usr/bin/open` with an argument
  list, so nothing in a URL, a rule or a profile name can become a command.
- **The log names hosts, not links.** `~/Library/Logs/linkrouter.log` records
  the app, the folder, the chosen browser and the link's scheme and host. Paths
  and query strings, where sign-in codes and reset tokens travel, are never
  written. The file is readable by you only and stays under 256 KiB
  ([ADR 0005](docs/adr/0005-the-log-names-hosts-not-links.md)).
- **It reads two files of yours.** The rules file, and a Chromium browser's
  `Local State` when a rule names a profile by its display name.

## Scope notes

**The rules file is trusted.** Whoever can write `~/.config/linkrouter/rules`
decides which app your links open in. That is the same person who could change
your default browser, so it is not a boundary Linkrouter defends.

**The folder comes from the app in front.** An app can put any path in its
window's `AXDocument`, so a hostile app could pick which of your rules applies
to a link clicked in it. It cannot pick an app that no rule names.

**Ad-hoc signed.** Linkrouter is built on your Mac from source and has no
Developer ID signature or hardened runtime. macOS keys the Accessibility grant
to the binary, which is why every upgrade asks for it again.
