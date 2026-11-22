#!/bin/sh
# Build Linkrouter.app, install it to ~/Applications, register it with macOS.
set -eu
cd "$(dirname "$0")"
./build.sh

app="$HOME/Applications/Linkrouter.app"
mkdir -p "$HOME/Applications"
rm -rf "$app"
cp -R build/Linkrouter.app "$app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"

if [ ! -f "$HOME/.config/linkrouter/rules" ]; then
  mkdir -p "$HOME/.config/linkrouter"
  cp rules.example "$HOME/.config/linkrouter/rules"
  echo "wrote ~/.config/linkrouter/rules from rules.example: edit it"
fi

echo "installed $app"
echo "make it the default browser: $app/Contents/MacOS/linkrouter --set-default"
