# 4. Profiles by the name Chrome shows

Date: 2026-11-22
Status: accepted

## Context

Chrome opens a profile with `--profile-directory=Profile 2`, but nobody knows
their profiles by directory: the menu says "Work" and "Acme". The mapping is in
the browser's `Local State` file, under `profile.info_cache`, which lists each
directory with its display name.

## Decision

A rule may name the profile either way. Linkrouter first looks for a profile
with that display name and uses its directory, the alphabetically first one if
two share a name. Only when no name matches does it take the rule as a
directory in `info_cache`. This works for Google Chrome, Chrome Beta, Chromium
and Brave, whose support folders are listed in `Sources/Rules/Rules.swift`.

A profile it cannot resolve never reaches the browser: an unknown name, a
missing or broken `Local State`, or a profile on a browser without profiles.
Linkrouter logs the reason and shows an alert that names the known profiles.
The link opens only on "Open anyway", in the browser's last used profile. This
alert is the one window Linkrouter shows, an exception to ADR 0003.

Amended 2026-11-23. Until then, a directory matched before a display name, and
an unresolved profile went to Chrome unchanged in the hope that Chrome reports
it. Chrome reports nothing: it silently creates an empty profile in a new
directory of that spelling. A rule `Google Chrome: Pareo` for the profile shown
as "Pareo" (directory `Default`) once made Chrome create an empty directory
`Pareo`, and from then on every link matched that directory and opened signed
out.

Amended 2026-11-24. On macOS 27 the app may not read another app's data, and
macOS refuses without asking (`kTCCServiceSystemPolicyAppDataDetailed does not
allow prompting`), so names do not resolve for a clicked link. A command run in
a terminal can be allowed what the app is not, so `--which` still resolves them.
Without `Local State`, a profile is taken only if it is spelled `Default` or
`Profile <number>` and that directory exists, which macOS still answers. Full
Disk Access would restore names, but is far too much for that.

A profile is opened with `open -na <app> --args --profile-directory=...`. The
`-n` starts a short-lived instance that hands the link to the running browser
in that profile and exits.

## Consequences

The shape of `Local State` is Chromium's, undocumented, and was read from the
file itself. If it changes, profile names stop resolving and only directories
keep working.
