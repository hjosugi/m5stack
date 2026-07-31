#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ ${1:-} == --allow-reset && $# == 1 ]] || die "使用方法: $0 --allow-reset（ポートを開くとリセットする可能性があります）"
require_command arduino-cli
load_local_env
require_model_config
verify_bound_device
require_port_access > /dev/null
configure_arduino_env

warn "シリアルモニターを開きます。DTR/RTSにより本体がリセットする可能性があります。"
exec arduino-cli --additional-urls "$M5_BOARD_INDEX_URL" monitor --port "$M5_PORT" --config baudrate=115200
