#!/bin/bash
# Refresh the opt-in Finder asset from the same Remotion scene used by the video.
set -euo pipefail
cd "$(dirname "$0")"
npm run background
ffmpeg -y -hide_banner -loglevel error -i renders/finder-background.png \
  -vf scale=960:600 -frames:v 1 ../../scripts/installer-assets/remotion-background.png
