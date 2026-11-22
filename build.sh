#!/bin/sh
# Build build/Linkrouter.app and sign it for this Mac. Needs only swiftc.
set -eu
cd "$(dirname "$0")"

app="build/Linkrouter.app"
rm -rf build
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/"
swiftc -O -o "$app/Contents/MacOS/linkrouter" main.swift
codesign --force --sign - --identifier dev.kaleve.linkrouter "$app"
echo "built $app"
