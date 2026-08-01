#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command arduino-cli
configure_arduino_env

while IFS= read -r fqbn || [[ -n $fqbn ]]; do
  [[ -z $fqbn || $fqbn == \#* ]] && continue
  "$SCRIPT_DIR/build-ci-target.sh" "$fqbn"
done < "$M5_REPO_ROOT/config/ci-boards.txt"

"$SCRIPT_DIR/build-ci-target.sh" cardputer-screen-link

log "Arduinoビルドマトリクスが完了しました。"
