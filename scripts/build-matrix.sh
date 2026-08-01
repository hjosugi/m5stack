#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command arduino-cli
configure_arduino_env

while IFS= read -r fqbn || [[ -n $fqbn ]]; do
  [[ -z $fqbn || $fqbn == \#* ]] && continue
  build_dir="$M5_REPO_ROOT/.local/build/matrix/$(fqbn_slug "$fqbn")"
  log "ビルド: $fqbn"
  arduino_cli compile \
    --fqbn "$fqbn" \
    --build-path "$build_dir" \
    --warnings all \
    "$M5_REPO_ROOT/firmware/hello_m5"
done < "$M5_REPO_ROOT/config/ci-boards.txt"

"$M5_REPO_ROOT/cardputer/screen-link/build.sh" --ci

log "Arduinoビルドマトリクスが完了しました。"
