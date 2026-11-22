# 6. Installed in /Applications, never run from the Cellar

Date: 2026-11-22
Status: accepted

## Context

Homebrew builds the app into its Cellar, under a folder named after the
version, and removes that folder on the next upgrade. A default browser
registered there would point at a deleted app after every `brew upgrade`.
Version 1.0.0 installed into `~/Applications`, while every other app in this
fleet goes into `/Applications`, so its instructions read differently for no
gain.

## Decision

`make install` copies the app to `/Applications`, as Taurine and Sesam do, and
registers it with Launch Services. Homebrew installs the app and the
`linkrouter` command, and its caveats say to copy the app to `/Applications`.
The default browser is recorded by bundle identifier, so once the old copy is
unregistered and removed the new one takes over without `--set-default` being
run again. `make install` does that for a copy in `~/Applications`.

## Consequences

After a Homebrew upgrade the copy in `/Applications` is replaced by hand, and
Accessibility is granted again, as for every ad-hoc signed app here.
