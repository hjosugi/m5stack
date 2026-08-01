#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command bash
require_command actionlint
require_command shellcheck
require_command shfmt
require_command task
require_command uv
require_command python3

[[ -f $M5_REPO_ROOT/Taskfile.yml ]] || die "Taskfile.ymlがありません。"
[[ ! -e $M5_REPO_ROOT/Makefile ]] || die "MakefileはTaskfile.ymlへ移行済みです。"
task --dir "$M5_REPO_ROOT" --list-all > /dev/null

mapfile -d '' shell_files < <(
  find \
    "$M5_REPO_ROOT/scripts" \
    "$M5_REPO_ROOT/tests" \
    "$M5_REPO_ROOT/cardputer" \
    "$M5_REPO_ROOT/stackchan" \
    -type f -name '*.sh' -print0 | sort -z
)
((${#shell_files[@]} > 0)) || die "検査対象のShellスクリプトがありません。"

for shell_file in "${shell_files[@]}"; do
  bash -n "$shell_file"
done
shellcheck -x "${shell_files[@]}"
shfmt -d -i 2 -ci -sr "${shell_files[@]}"
actionlint "$M5_REPO_ROOT"/.github/workflows/*.yml

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
"$M5_REPO_ROOT/tests/test-taskfile.sh"
"$M5_REPO_ROOT/tests/test-safety-gates.sh"
uv run --project "$M5_REPO_ROOT/pc/screen-link" --frozen \
  python -m unittest discover -s "$M5_REPO_ROOT/pc/screen-link/tests" -v
python3 "$M5_REPO_ROOT/scripts/check-site.py" "$M5_REPO_ROOT/site"
"$M5_REPO_ROOT/scripts/audit-public-tree.sh"
git -C "$M5_REPO_ROOT" diff --check
log "静的検査と単体テストが完了しました。"
