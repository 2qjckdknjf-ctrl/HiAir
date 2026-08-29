#!/bin/sh
# Exit 0 if stdin paths include iOS *app* source (not ci_scripts, web, or docs).
# Exit 2 otherwise.
# Paths are repository-relative, one per line.
set -eu

found=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    mobile/ios/HiAir/*|mobile/ios/HiAirTests/*|mobile/ios/project.yml|mobile/ios/HiAir.xcodeproj/*|mobile/ios/ExportOptions.plist|mobile/ios/HiAir.xcworkspace/*)
      found=1
      ;;
  esac
done

if [ "$found" -eq 1 ]; then
  exit 0
fi
exit 2
