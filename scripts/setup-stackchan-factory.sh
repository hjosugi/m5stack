#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

"$SCRIPT_DIR/fetch-stackchan.sh"

idf_path="$M5_REPO_ROOT/.local/upstream/esp-idf"
export IDF_TOOLS_PATH="$M5_REPO_ROOT/.local/espressif"

log "ESP-IDF $ESP_IDF_VERSION のESP32-S3ツールチェーンをローカルへ導入します。"
# Nix版esptoolが設定するPYTHONPATHをESP-IDF専用venvへ混在させない。
env -u PYTHONPATH "$idf_path/install.sh" esp32s3
log "ESP-IDFのセットアップが完了しました。実機は操作していません。"
