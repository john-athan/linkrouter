# 5. The log names hosts, not links

Date: 2026-11-22
Status: accepted

## Context

A rule that picks a surprising browser has to be explainable, so Linkrouter
writes a line per link. Version 1.0.0 wrote the whole URL, without a limit, to
a file with the default mode. A default browser sees every link you click, and
URLs carry what their senders put in them: sign-in codes, password reset
tokens, magic links, search terms. That made the log a complete browsing
history in plain text, kept forever.

## Decision

A line names the app, the folder, the chosen browser and the link's scheme and
host. Path, query, fragment, user, password and port are never written: the
choice depends on the folder and never on the link, so none of that explains
anything. The file is created 0600. Past 256 KiB the older half is dropped, at
a line boundary. A log whose mode is not 0600 was written by 1.0.0 and is
started over instead of kept.

## Consequences

The log can show that a link to `github.com` went to the work profile, but not
which page. Upgrading from 1.0.0 deletes that version's history of full URLs,
which is intended.
