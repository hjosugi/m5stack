#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC2034

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export M5_SYSFS_ROOT="$TEST_ROOT/sys"
export M5_DEV_ROOT="$TEST_ROOT/dev"
export M5_BY_ID_ROOT="$TEST_ROOT/dev/serial/by-id"
export M5_ENV_FILE="$TEST_ROOT/.env"

mkdir -p "$M5_SYSFS_ROOT/1-1" "$M5_SYSFS_ROOT/1-1:1.0/tty/ttyACM0" "$M5_BY_ID_ROOT"
printf '303a\n' > "$M5_SYSFS_ROOT/1-1/idVendor"
printf '1001\n' > "$M5_SYSFS_ROOT/1-1/idProduct"
printf 'Espressif\n' > "$M5_SYSFS_ROOT/1-1/manufacturer"
printf 'USB JTAG/serial debug unit\n' > "$M5_SYSFS_ROOT/1-1/product"
printf 'test-serial\n' > "$M5_SYSFS_ROOT/1-1/serial"
: > "$M5_DEV_ROOT/ttyACM0"
ln -s ../../ttyACM0 "$M5_BY_ID_ROOT/usb-test-if00"

# shellcheck source=../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

detect_m5_usb
[[ $DETECTED_VID == 303a ]]
[[ $DETECTED_PID == 1001 ]]
[[ $DETECTED_SERIAL == test-serial ]]
[[ $DETECTED_PORT == "$M5_BY_ID_ROOT/usb-test-if00" ]]

M5_MODEL=M5StackChan
M5_FQBN=m5stack:esp32:m5stack_cores3
M5_PORT=$DETECTED_PORT
M5_USB_SERIAL=$DETECTED_SERIAL
M5_USB_VID=$DETECTED_VID
M5_USB_PID=$DETECTED_PID
write_local_env

unset M5_MODEL M5_FQBN M5_PORT M5_USB_SERIAL M5_USB_VID M5_USB_PID
load_local_env
[[ $M5_MODEL == M5StackChan ]]
[[ $M5_USB_SERIAL == test-serial ]]
[[ $(stat -c %a "$M5_ENV_FILE") == 600 ]]

printf 'UNSUPPORTED=value\n' >> "$M5_ENV_FILE"
if (load_local_env) > /dev/null 2>&1; then
  printf '未対応の.envキーを拒否できませんでした。\n' >&2
  exit 1
fi

printf 'common.sh tests: OK\n'
