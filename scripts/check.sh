#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command actionlint
require_command bash
require_command mkdocs
require_command node
require_command python3
require_command shellcheck
require_command shfmt
require_command task
require_command uv

[[ -f $M5_REPO_ROOT/Taskfile.yml ]] || die "Taskfile.ymlがありません。"
[[ ! -e $M5_REPO_ROOT/Makefile ]] || die "MakefileはTaskfile.ymlへ移行済みです。"
[[ ! -e $M5_REPO_ROOT/site ]] || die "旧site/が残っています。Pagesの正本はdocs/です。"
task --dir "$M5_REPO_ROOT" --list-all > /dev/null

if rg --hidden --glob '!.git/**' --glob '!.local/**' \
  '^(<<<<<<<|\|\|\|\|\|\|\||=======|>>>>>>>)' "$M5_REPO_ROOT" > /dev/null; then
  die "競合マーカーが残っています。"
fi

mapfile -d '' shell_files < <(
  find \
    "$M5_REPO_ROOT/scripts" \
    "$M5_REPO_ROOT/tests" \
    "$M5_REPO_ROOT/cardputer" \
    "$M5_REPO_ROOT/stackchan" \
    "$M5_REPO_ROOT/pc" \
    -type d -name .venv -prune -o \
    -type f -name '*.sh' -print0 | sort -z
)
((${#shell_files[@]} > 0)) || die "検査対象のShellスクリプトがありません。"

for shell_file in "${shell_files[@]}"; do
  bash -n "$shell_file"
done
shellcheck -x "${shell_files[@]}"
shfmt -d -i 2 -ci -sr "${shell_files[@]}"
actionlint "$M5_REPO_ROOT"/.github/workflows/*.yml

mapfile -d '' json_files < <(git -C "$M5_REPO_ROOT" ls-files -z '*.json')
for json_file in "${json_files[@]}"; do
  jq empty "$M5_REPO_ROOT/$json_file"
done

mapfile -d '' python_files < <(git -C "$M5_REPO_ROOT" ls-files -z '*.py')
if ((${#python_files[@]} > 0)); then
  PYTHONPYCACHEPREFIX="$M5_REPO_ROOT/.local/pycache" \
    python3 -m py_compile "${python_files[@]/#/$M5_REPO_ROOT/}"
fi

python3 - "$M5_REPO_ROOT" << 'PY'
import sys
import tomllib
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
for path in sorted(repo_root.rglob("*.yml")):
    if ".git" not in path.parts and ".local" not in path.parts:
        with path.open(encoding="utf-8") as stream:
            yaml.safe_load(stream)
for path in sorted(repo_root.rglob("*.toml")):
    if ".git" not in path.parts and ".local" not in path.parts:
        with path.open("rb") as stream:
            tomllib.load(stream)
PY

python3 "$M5_REPO_ROOT/scripts/check-markdown-links.py"

node --check "$M5_REPO_ROOT/pc/screen-link/src/m5_screen_link/static/app.js"

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
"$M5_REPO_ROOT/scripts/audit-public-tree.sh"
mkdocs build --strict --config-file "$M5_REPO_ROOT/mkdocs.yml"
git -C "$M5_REPO_ROOT" diff --check
log "静的検査、単体テスト、Markdownサイトの検証が完了しました。"
