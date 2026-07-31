#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command bash
require_command shellcheck
require_command shfmt

mapfile -d '' shell_files < <(find "$M5_REPO_ROOT/scripts" "$M5_REPO_ROOT/tests" -type f -name '*.sh' -print0 | sort -z)
((${#shell_files[@]} > 0)) || die "検査対象のShellスクリプトがありません。"

for shell_file in "${shell_files[@]}"; do
  bash -n "$shell_file"
done
shellcheck -x "${shell_files[@]}"
shfmt -d -i 2 -ci -sr "${shell_files[@]}"

awk -F '\t' '
  /^#/ || NF == 0 { next }
  NF != 5 { printf "config/boards.tsv:%d: 列数が5ではありません\n", NR > "/dev/stderr"; exit 1 }
  seen[$1]++ { printf "config/boards.tsv:%d: keyが重複しています: %s\n", NR, $1 > "/dev/stderr"; exit 1 }
  $5 !~ /^[0-9]+$/ { printf "config/boards.tsv:%d: flash_bytesが数値ではありません\n", NR > "/dev/stderr"; exit 1 }
' "$M5_REPO_ROOT/config/boards.tsv"

awk -F '|' '
  /^#/ || NF == 0 { next }
  NF != 5 { printf "config/upstream.lock:%d: 列数が5ではありません\n", NR > "/dev/stderr"; exit 1 }
  $4 !~ /^[0-9a-f]{40}$/ { printf "config/upstream.lock:%d: commitが40桁SHAではありません\n", NR > "/dev/stderr"; exit 1 }
' "$M5_REPO_ROOT/config/upstream.lock"

"$M5_REPO_ROOT/tests/test-common.sh"
"$M5_REPO_ROOT/tests/test-safety-gates.sh"
"$M5_REPO_ROOT/scripts/audit-public-tree.sh"
git -C "$M5_REPO_ROOT" diff --check
log "静的検査と単体テストが完了しました。"
