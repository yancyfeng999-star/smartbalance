#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tuist generate --no-open
xcodebuild test \
  -workspace SmartBalance.xcworkspace \
  -scheme SmartBalance \
  -destination 'platform=macOS' \
  -only-testing:DomainTests \
  -only-testing:InfrastructureTests \
  -only-testing:AppTests
# 测试会编出 智余.app 并注册到启动台；测完立刻清掉，只留 /Applications 那一份
KEEP_RUNNING=1 "$(dirname "$0")/cleanup-duplicate-apps.sh" || true
