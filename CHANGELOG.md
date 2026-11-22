# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); `oss release` reads the
`## [version]` sections.

## [Unreleased]

## [1.0.1] - 2026-11-22

- Installs to `/Applications` like the other apps here; `make install` moves a 1.0.0 copy out of `~/Applications`, and it stays the default browser
- The log names each link by its host only, never its path or query, is readable by you only and stays under 256 KiB; a 1.0.0 log full of whole URLs is started over
- `linkrouter` goes on the PATH with `make install` too, and has `--help`
- `make uninstall` unregisters the app and removes the log, keeping your rules
- SECURITY.md says what Linkrouter promises; docs/adr records why it works the way it does
- Tests for the rules, profile lookup and log in `Tests/`, on the fleet's shared harness

## [1.0.0] - 2026-11-22

- First release: a default browser that picks the browser and profile by the folder of the window you clicked in
- `--set-default` registers the copy it runs from, so a Homebrew install can become the default browser
