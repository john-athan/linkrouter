#!/bin/sh
# Every check this project has, in one script.
#
# Run it directly, or through `oss check linkrouter`, or let CI call it. The
# rules are tested through `linkrouter --which <folder>`, a dry run that needs
# no window, no Accessibility permission and no browser.
set -eu
cd "$(dirname "$0")/.."

fail=0
step() { printf '\n== %s\n' "$1"; }

step "Info.plist"
plutil -lint Info.plist

step "build"
./build.sh

step "rules"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export LINKROUTER_RULES="$tmp/rules" LINKROUTER_LOG="$tmp/log"
bin=build/Linkrouter.app/Contents/MacOS/linkrouter

cat > "$LINKROUTER_RULES" <<RULES
# comment
~/work                 Google Chrome: Work
~/work/clients/acme/   Google Chrome: Profile 3
/srv	Firefox
/opt one space Safari
*                      Brave Browser
RULES

# expect <folder> <first line of --which>
expect() {
  got=$("$bin" --which "$1" | head -1)
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: got '$got', want '$2'"; fail=1; fi
}
w="$HOME/work"
expect "$w"                       "$w -> Google Chrome: Work"
expect "$w/platform/app"          "$w -> Google Chrome: Work"
expect "$w/clients/acme"          "$w/clients/acme -> Google Chrome: Profile 3"
expect "$w/clients/acme/code"     "$w/clients/acme -> Google Chrome: Profile 3"
expect "$w/clients/acmex"         "$w -> Google Chrome: Work"
expect "$HOME/workshop"           "* -> Brave Browser"
expect "/srv/x"                   "/srv -> Firefox"
expect "/opt/x"                   "* -> Brave Browser"
expect ""                         "* -> Brave Browser"

if grep -q "skipped line without a gap" "$LINKROUTER_LOG"; then echo "ok   a one-space line is skipped and logged"
else echo "FAIL a one-space line was not logged"; fail=1; fi

printf '' > "$LINKROUTER_RULES"
expect "$w" "no rule"

step "rules.example parses completely"
LINKROUTER_RULES=rules.example LINKROUTER_LOG="$tmp/log2" "$bin" --which / >/dev/null
if [ -s "$tmp/log2" ]; then echo "FAIL:"; cat "$tmp/log2"; fail=1; else echo "ok"; fi

exit $fail
