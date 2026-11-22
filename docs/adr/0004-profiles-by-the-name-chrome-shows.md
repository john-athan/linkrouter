# 4. Profiles by the name Chrome shows

Date: 2026-11-22
Status: accepted

## Context

Chrome opens a profile with `--profile-directory=Profile 2`, but nobody knows
their profiles by directory: the menu says "Work" and "Acme". The mapping is in
the browser's `Local State` file, under `profile.info_cache`, which lists each
directory with its display name.

## Decision

A rule may name the profile either way. When it is not a directory in
`info_cache`, Linkrouter looks for a profile with that display name and uses its
directory, the alphabetically first one if two share a name. Anything it cannot
resolve, including a missing or broken `Local State`, is passed to Chrome
unchanged, so Chrome reports the problem instead of Linkrouter guessing. This
works for Google Chrome, Chrome Beta, Chromium and Brave, whose support
folders are listed in `Sources/Rules/Rules.swift`.

A profile is opened with `open -na <app> --args --profile-directory=...`. The
`-n` starts a short-lived instance that hands the link to the running browser
in that profile and exits.

## Consequences

The shape of `Local State` is Chromium's, undocumented, and was read from the
file itself. If it changes, profile names stop resolving and only directories
keep working.
