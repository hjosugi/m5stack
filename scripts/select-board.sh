#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf '使用方法: %s list | <key>\n' "$0" >&2
}

if [[ ${1:-} == list ]]; then
  printf '%-12s %-18s %-38s %-9s %s\n' KEY MODEL FQBN CHIP FLASH
  while IFS=$'\t' read -r key model fqbn chip flash_bytes; do
    [[ -z $key || $key == \#* ]] && continue
    printf '%-12s %-18s %-38s %-9s %s MiB\n' "$key" "$model" "$fqbn" "$chip" "$((flash_bytes / 1024 / 1024))"
  done < "$M5_REPO_ROOT/config/boards.tsv"
  exit 0
fi

(($# == 1)) || {
  usage
  exit 2
}

[[ -f $M5_ENV_FILE ]] || die "先に ./scripts/init-env.sh を実行してください。"
load_local_env
lookup_board_key "$1" || die "不明な型番キーです: $1"

M5_MODEL=$BOARD_MODEL
M5_FQBN=$BOARD_FQBN
write_local_env

log "型番を $M5_MODEL に設定しました。"
log "FQBN: $M5_FQBN"
warn "この設定は本体印字と一致する場合だけ使用してください。"
