#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
exec "$HOME/ios/release/testflight.sh" --project Inkling.xcodeproj --scheme Inkling --upload-only "$@"
