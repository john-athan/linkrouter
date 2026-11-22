# Third-party material in Linkrouter

Linkrouter is MIT licensed. This file records anything in the repository that
originated elsewhere.

## Dependencies

None, and there is no manifest that could acquire one. `tools/build-app.sh` hands
`main.swift` to `swiftc`; there is no `Package.swift`, no Xcode project and no
package manager. The app links Apple's SDK frameworks only (AppKit and
ApplicationServices), which are used under the Apple Developer Program
agreement and are not redistributed here.

## Programs Linkrouter starts

It runs `/usr/bin/open` to hand a link to the browser a rule names, with the
arguments passed directly and never through a shell. The browsers are the
user's own and none is bundled.

## Formats it reads

To accept a Chromium profile by its display name, Linkrouter reads the
`profile.info_cache` object from the browser's `Local State` JSON file. The
shape was established by inspecting that file on this machine, not by reading
Chromium's source.
