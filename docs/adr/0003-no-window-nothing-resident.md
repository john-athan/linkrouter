# 3. No window, and nothing resident

Date: 2026-11-22
Status: accepted

## Context

A default browser is started by macOS for the first link and could stay
running as a menu bar app with a settings window. Everything such a window
would show is already in the rules file, and a process that stays running is
one that holds the Accessibility permission all day.

## Decision

`LSUIElement` and the `.prohibited` activation policy: no Dock icon, no menu,
no window, never the active app. macOS starts Linkrouter for a link, and it
quits five seconds after the last one. The rules file is the interface, and
`linkrouter --which <folder>` answers "what would happen" without opening
anything.

## Consequences

There is no settings screen and no menu bar icon to discover the app by, so
the README and the Homebrew caveats carry the setup. A burst of links is
handled by one process, since each one resets the five seconds.
