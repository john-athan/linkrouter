# 1. The folder comes from the window, through Accessibility

Date: 2026-11-22
Status: accepted

## Context

A link arrives at a default browser as a URL and nothing else. macOS does not
say which app sent it, let alone which folder that app was working in. The
question Linkrouter answers, "where was I when I clicked this", needs a second
source.

The candidates were the frontmost app's window title, its process's working
directory, and the window's `AXDocument` attribute. Titles are free text and
change whenever a program in a terminal sets one: Claude Code, `vim` and test
runners all do. A process's working directory belongs to the terminal, not to
the shell inside it, and reading another process's state needs more than an
unprivileged app gets. `AXDocument` is the standard way a window names the file
or folder it shows, and Ghostty sets it from the shell's working directory
(OSC 7) at every prompt, independently of the title.

## Decision

Read `AXDocument` of the focused window of the frontmost app when a link
arrives, accept it only when it is a `file://` URL, and route by its path. An
app that names no folder gets the `*` rule.

## Consequences

Linkrouter needs the Accessibility permission. Without it, nothing breaks:
every link goes to `*`. Terminals that do not set `AXDocument` route
everything to `*` too, and so do apps like Slack and Mail that have no folder.
The folder is whatever the app in front claims, which SECURITY.md states.
