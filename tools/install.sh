#!/usr/bin/env bash
# Copies what ships (the same set .pkgmeta leaves in the package) into a game's AddOns folder as "Warmth", with
# the version from VERSION in the toc, so the working tree can be tried in game before a release.
#
#   tools/install.sh "/e/World of Warcraft/_forever_/Interface/AddOns"
set -euo pipefail
cd "$(dirname "$0")/.."
addons=${1:?usage: tools/install.sh <AddOns folder>}
[ -d "$addons" ] || { echo "not a folder: $addons" >&2; exit 1; }
dest="$addons/Warmth"
rm -rf "$dest"
mkdir -p "$dest"
cp -r Core UI Libs Media Warmth.toc LICENSE LICENSE-GPL-3.0.md README.md CHANGELOG.md "$dest/"
rm -f "$dest/Media/logo-512.png" "$dest/Media/logo-square-512.png"
sed -i "s/@project-version@/$(tr -d ' \t\r\n' < VERSION)/" "$dest/Warmth.toc"
echo "installed Warmth $(tr -d ' \t\r\n' < VERSION) into $dest"
