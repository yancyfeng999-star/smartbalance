#!/usr/bin/env bash
# 本地开源交付门禁：许可证、公开文档、第三方声明和敏感文件名检查。
# 不联网、不修改工作区、不读取 Keychain、不输出文件内容中的秘密。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

failures=0

fail() {
  echo "open-source-check: $*" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    fail "缺少文件：$path"
  fi
}

require_text() {
  local path="$1"
  local text="$2"
  if [[ ! -f "$path" ]] || ! grep -Fq "$text" "$path"; then
    fail "文件缺少必要内容：$path -> $text"
  fi
}

contains_pattern() {
  local pattern="$1"
  local path="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$path" >/dev/null
  else
    grep -En "$pattern" "$path" >/dev/null
  fi
}

required_files=(
  LICENSE
  README.md
  CONTRIBUTING.md
  SECURITY.md
  CODE_OF_CONDUCT.md
  THIRD_PARTY_NOTICES.md
  docs/ARCHITECTURE.md
  docs/DATA_AND_PRIVACY.md
  docs/PROVIDER_DEVELOPMENT.md
  docs/RELEASE_CHECKLIST.md
  .github/PULL_REQUEST_TEMPLATE.md
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
)

for path in "${required_files[@]}"; do
  require_file "$path"
done

require_text LICENSE "Apache License"
require_text LICENSE "Version 2.0, January 2004"
require_text LICENSE "SPDX-License-Identifier: Apache-2.0"
require_text LICENSE "2. Grant of Copyright License"
require_text LICENSE "3. Grant of Patent License"
require_text LICENSE "END OF TERMS AND CONDITIONS"

for marker in CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md THIRD_PARTY_NOTICES.md Apache-2.0; do
  require_text README.md "$marker"
done

require_text THIRD_PARTY_NOTICES.md "MenuBarExtraAccess"
require_text THIRD_PARTY_NOTICES.md "https://github.com/orchetect/MenuBarExtraAccess"
require_text THIRD_PARTY_NOTICES.md "1.3.1"
require_text THIRD_PARTY_NOTICES.md "MIT"

public_docs=(
  README.md
  CONTRIBUTING.md
  SECURITY.md
  CODE_OF_CONDUCT.md
  THIRD_PARTY_NOTICES.md
  docs/ARCHITECTURE.md
  docs/DATA_AND_PRIVACY.md
  docs/PROVIDER_DEVELOPMENT.md
  docs/RELEASE_CHECKLIST.md
)

for path in "${public_docs[@]}"; do
  if [[ -f "$path" ]] && contains_pattern '/Users/|/private/var/' "$path"; then
    fail "公开文档包含本机绝对路径：$path"
  fi
done

while IFS= read -r -d '' path; do
  case "$path" in
    .env|.env.*|*.p12|*.p8|*.mobileprovision|*.provisionprofile|*.pem|*.keychain-db)
      fail "仓库文件名疑似包含凭据或证书：$path"
      ;;
  esac
done < <(git ls-files -co --exclude-standard -z)

if (( failures > 0 )); then
  echo "open-source-check: FAILED ($failures issue(s))" >&2
  exit 1
fi

echo "open-source-check: PASS"
