#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p renders public/assets
xcrun actool ../../output/app-icons/msgblast.icon --compile renders --platform macosx --minimum-deployment-target 15.0 --app-icon msgblast --output-partial-info-plist renders/icon-info.plist
swift export.swift renders/msgblast.icns public/assets/msgblast.png 1024
swift export.swift /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns public/assets/applications.png 512
python3 prepare-assets.py
