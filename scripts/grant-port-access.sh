#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command pkexec
require_command setfacl
load_local_env
verify_bound_device

resolved_port=$(readlink -f -- "$M5_PORT")
[[ $resolved_port == /dev/ttyACM* || $resolved_port == /dev/ttyUSB* ]] || die "想定外のデバイスノードです: $resolved_port"

if [[ -r $resolved_port && -w $resolved_port ]]; then
  log "$resolved_port は既に読み書き可能です。"
  exit 0
fi

log "$resolved_port に現在のユーザーだけの一時ACLを付与します。"
pkexec setfacl -m "u:$(id -un):rw" -- "$resolved_port"
[[ -r $resolved_port && -w $resolved_port ]] || die "ACL付与後もポートへアクセスできません。"
log "権限を付与しました。USBを抜くとこのACLは失われます。"
