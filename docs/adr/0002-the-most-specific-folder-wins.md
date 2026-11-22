# 2. The most specific folder wins, and the rules are read on every link

Date: 2026-11-22
Status: accepted

## Context

Rules overlap by nature: `~/work` for the work profile, `~/work/clients/acme`
for one client inside it. A first-match list would make the order of lines
significant, and the usual bug in such lists is a general rule placed above a
specific one that then never fires.

## Decision

A rule applies when its folder is the clicked folder or contains it, path
component by path component, so `~/work` contains `~/work/x` but not
`~/workshop`. Of the rules that apply, the longest folder wins, and `*` only
applies when nothing else does. The order of lines does not matter.

The file is read again on every link. It is a few lines, and reading it costs
less than a file watcher would, while an edit counts at once and there is no
reload step to forget.

## Consequences

Two rules for the same folder are a tie, and the first one wins. A line
without a gap of two spaces or a tab is not a rule: it is skipped and logged,
since guessing where a folder name with spaces ends would route a link wrongly
rather than visibly not at all.
