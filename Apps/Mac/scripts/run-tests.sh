#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tuist generate --no-open
xcodebuild test \
  -workspace SmartBalance.xcworkspace \
  -scheme SmartBalance \
  -destination 'platform=macOS' \
  -only-testing:DomainTests \
  -only-testing:InfrastructureTests
