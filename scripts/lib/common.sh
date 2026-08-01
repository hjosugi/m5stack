#!/usr/bin/env bash
# shellcheck disable=SC2034

M5_LIB_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
M5_REPO_ROOT=$(CDPATH='' cd -- "$M5_LIB_DIR/../.." && pwd)
M5_ENV_FILE=${M5_ENV_FILE:-"$M5_REPO_ROOT/.env"}
M5_SYSFS_ROOT=${M5_SYSFS_ROOT:-/sys/bus/usb/devices}
M5_DEV_ROOT=${M5_DEV_ROOT:-/dev}
M5_BY_ID_ROOT=${M5_BY_ID_ROOT:-/dev/serial/by-id}
M5_ESPTOOL_BAUD=${M5_ESPTOOL_BAUD:-115200}

# versions.envはGit管理された固定値だけを含む。
# shellcheck source=../../versions.env
source "$M5_REPO_ROOT/versions.env"

log() {
  printf '%s\n' "$*"
}

warn() {
  printf '警告: %s\n' "$*" >&2
}

die() {
  printf 'エラー: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" > /dev/null 2>&1 || die "$1 が見つかりません。先に direnv allow または nix develop を実行してください。"
}

read_usb_attr() {
  local device_path=$1
  local attr=$2
  local attr_path="$device_path/$attr"

  if [[ -r $attr_path ]]; then
    tr -d '\000\r\n' < "$attr_path"
  fi
}

usb_id_is_supported() {
  case "$1" in
    303a:1001 | 10c4:ea60 | 1a86:55d4 | 1a86:7523 | 0403:6001)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

hash_identifier() {
  require_command sha256sum
  printf '%s' "$1" | sha256sum | cut -c 1-12
}

redact_device_identity() {
  sed -E \
    -e 's#/dev/serial/by-id/[^[:space:]]+#/dev/serial/by-id/[redacted]#g' \
    -e '/(^|[[:space:]])((Base|BASE|Device)[[:space:]]+)?MAC([[:space:]]|:)/Id' \
    -e '/Serial(Number| number)[[:space:]]*:/Id'
}

load_local_env() {
  local line
  local key
  local value
  local line_number=0

  M5_MODEL=${M5_MODEL:-}
  M5_FQBN=${M5_FQBN:-}
  M5_PORT=${M5_PORT:-}
  M5_USB_SERIAL=${M5_USB_SERIAL:-}
  M5_USB_VID=${M5_USB_VID:-}
  M5_USB_PID=${M5_USB_PID:-}

  [[ -f $M5_ENV_FILE ]] || return 0

  while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    line=${line%$'\r'}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *=* ]] || die "$M5_ENV_FILE:$line_number は KEY=VALUE 形式ではありません。"
    key=${line%%=*}
    value=${line#*=}

    case "$key" in
      M5_MODEL | M5_FQBN | M5_PORT | M5_USB_SERIAL | M5_USB_VID | M5_USB_PID)
        ;;
      *)
        die "$M5_ENV_FILE:$line_number の未対応キー $key を拒否しました。"
        ;;
    esac

    [[ $value != *$'\n'* ]] || die "$M5_ENV_FILE:$line_number に改行を含む値は設定できません。"
    printf -v "$key" '%s' "$value"
    export "${key?}"
  done < "$M5_ENV_FILE"
}

write_local_env() {
  local variable_name
  local variable_value
  local temp_file

  for variable_name in M5_MODEL M5_FQBN M5_PORT M5_USB_SERIAL M5_USB_VID M5_USB_PID; do
    variable_value=${!variable_name-}
    [[ $variable_value != *$'\n'* && $variable_value != *$'\r'* ]] || die "$variable_name に改行は設定できません。"
  done

  umask 077
  mkdir -p "$(dirname -- "$M5_ENV_FILE")"
  temp_file=$(mktemp "${M5_ENV_FILE}.tmp.XXXXXX")
  {
    printf '# 実機固有値。Gitへ追加しないこと。\n'
    printf 'M5_MODEL=%s\n' "${M5_MODEL:-}"
    printf 'M5_FQBN=%s\n' "${M5_FQBN:-}"
    printf 'M5_PORT=%s\n' "${M5_PORT:-}"
    printf 'M5_USB_SERIAL=%s\n' "${M5_USB_SERIAL:-}"
    printf 'M5_USB_VID=%s\n' "${M5_USB_VID:-}"
    printf 'M5_USB_PID=%s\n' "${M5_USB_PID:-}"
  } > "$temp_file"
  chmod 600 "$temp_file"
  mv -f -- "$temp_file" "$M5_ENV_FILE"
}

detect_m5_usb() {
  local device_path
  local vid
  local pid
  local serial
  local usb_id
  local tty_path
  local stable_path
  local resolved_port
  local resolved_stable
  local -a matches=()

  [[ -d $M5_SYSFS_ROOT ]] || die "USB sysfsが見つかりません: $M5_SYSFS_ROOT"

  shopt -s nullglob
  for device_path in "$M5_SYSFS_ROOT"/*; do
    [[ -r $device_path/idVendor && -r $device_path/idProduct ]] || continue
    vid=$(read_usb_attr "$device_path" idVendor)
    pid=$(read_usb_attr "$device_path" idProduct)
    usb_id="${vid,,}:${pid,,}"
    usb_id_is_supported "$usb_id" || continue

    serial=$(read_usb_attr "$device_path" serial)
    if [[ -n ${M5_USB_SERIAL:-} && $serial != "$M5_USB_SERIAL" ]]; then
      continue
    fi
    matches+=("$device_path")
  done
  shopt -u nullglob

  ((${#matches[@]} > 0)) || die "対応するM5/ESP32 USBデバイスが見つかりません。"
  ((${#matches[@]} == 1)) || die "対応デバイスが${#matches[@]}台あります。.envのM5_USB_SERIALで1台に固定してください。"

  DETECTED_SYSFS_PATH=${matches[0]}
  DETECTED_SYSFS_KEY=${DETECTED_SYSFS_PATH##*/}
  DETECTED_VID=$(read_usb_attr "$DETECTED_SYSFS_PATH" idVendor)
  DETECTED_PID=$(read_usb_attr "$DETECTED_SYSFS_PATH" idProduct)
  DETECTED_MANUFACTURER=$(read_usb_attr "$DETECTED_SYSFS_PATH" manufacturer)
  DETECTED_PRODUCT=$(read_usb_attr "$DETECTED_SYSFS_PATH" product)
  DETECTED_SERIAL=$(read_usb_attr "$DETECTED_SYSFS_PATH" serial)
  DETECTED_PORT=

  shopt -s nullglob
  for tty_path in "$M5_SYSFS_ROOT/${DETECTED_SYSFS_KEY}:"*/tty/*; do
    DETECTED_PORT="$M5_DEV_ROOT/${tty_path##*/}"
    break
  done
  shopt -u nullglob

  if [[ -n $DETECTED_PORT && -e $DETECTED_PORT && -d $M5_BY_ID_ROOT ]]; then
    resolved_port=$(readlink -f -- "$DETECTED_PORT")
    shopt -s nullglob
    for stable_path in "$M5_BY_ID_ROOT"/*; do
      [[ -L $stable_path ]] || continue
      resolved_stable=$(readlink -f -- "$stable_path")
      if [[ $resolved_stable == "$resolved_port" ]]; then
        DETECTED_PORT=$stable_path
        break
      fi
    done
    shopt -u nullglob
  fi
}

verify_bound_device() {
  local configured_port
  local detected_port

  [[ -n ${M5_USB_SERIAL:-} ]] || die ".envのM5_USB_SERIALが空です。./scripts/init-env.sh を実行してください。"
  [[ -n ${M5_USB_VID:-} && -n ${M5_USB_PID:-} ]] || die ".envのUSB IDが未設定です。"
  [[ -n ${M5_PORT:-} ]] || die ".envのM5_PORTが未設定です。"

  detect_m5_usb
  [[ $DETECTED_SERIAL == "$M5_USB_SERIAL" ]] || die "USBシリアルが設定対象と一致しません。"
  [[ ${DETECTED_VID,,} == "${M5_USB_VID,,}" && ${DETECTED_PID,,} == "${M5_USB_PID,,}" ]] || die "USB IDが設定対象と一致しません。"
  [[ -n $DETECTED_PORT && -e $DETECTED_PORT ]] || die "シリアルポートを確認できません。"

  configured_port=$(readlink -f -- "$M5_PORT")
  detected_port=$(readlink -f -- "$DETECTED_PORT")
  [[ $configured_port == "$detected_port" ]] || die "シリアルポートが設定対象と一致しません。"
}

lookup_board_key() {
  local requested_key=$1
  local key
  local model
  local fqbn
  local chip
  local flash_bytes

  while IFS=$'\t' read -r key model fqbn chip flash_bytes; do
    [[ -z $key || $key == \#* ]] && continue
    if [[ $key == "$requested_key" ]]; then
      BOARD_KEY=$key
      BOARD_MODEL=$model
      BOARD_FQBN=$fqbn
      BOARD_CHIP=$chip
      BOARD_FLASH_BYTES=$flash_bytes
      return 0
    fi
  done < "$M5_REPO_ROOT/config/boards.tsv"
  return 1
}

require_model_config() {
  local key
  local model
  local fqbn
  local chip
  local flash_bytes

  [[ -n ${M5_MODEL:-} && -n ${M5_FQBN:-} ]] || die "製品型番が未設定です。本体印字を確認し、./scripts/select-board.sh <key> を実行してください。"

  while IFS=$'\t' read -r key model fqbn chip flash_bytes; do
    [[ -z $key || $key == \#* ]] && continue
    if [[ $fqbn == "$M5_FQBN" && $model == "$M5_MODEL" ]]; then
      BOARD_KEY=$key
      BOARD_MODEL=$model
      BOARD_FQBN=$fqbn
      BOARD_CHIP=$chip
      BOARD_FLASH_BYTES=$flash_bytes
      return 0
    fi
  done < "$M5_REPO_ROOT/config/boards.tsv"

  die ".envのM5_MODELとM5_FQBNの組合せは対応表にありません。"
}

configure_arduino_env() {
  export ARDUINO_DIRECTORIES_DATA=${ARDUINO_DIRECTORIES_DATA:-"$M5_REPO_ROOT/.local/arduino/data"}
  export ARDUINO_DIRECTORIES_DOWNLOADS=${ARDUINO_DIRECTORIES_DOWNLOADS:-"$M5_REPO_ROOT/.local/arduino/downloads"}
  export ARDUINO_DIRECTORIES_USER=${ARDUINO_DIRECTORIES_USER:-"$M5_REPO_ROOT/.local/arduino/user"}
  export ARDUINO_BOARD_MANAGER_ADDITIONAL_URLS=${ARDUINO_BOARD_MANAGER_ADDITIONAL_URLS:-"$M5_BOARD_INDEX_URL"}

  mkdir -p "$ARDUINO_DIRECTORIES_DATA" "$ARDUINO_DIRECTORIES_DOWNLOADS" "$ARDUINO_DIRECTORIES_USER"
}

fqbn_slug() {
  local slug=$1
  slug=${slug//:/_}
  slug=${slug//,/_}
  slug=${slug//=/_}
  printf '%s\n' "$slug"
}

arduino_cli() {
  arduino-cli --additional-urls "$M5_BOARD_INDEX_URL" "$@"
}

device_hash() {
  [[ -n ${M5_USB_SERIAL:-} ]] || die "USBシリアルが未設定です。"
  hash_identifier "$M5_USB_SERIAL"
}

backup_marker_path() {
  local identifier
  identifier=$(device_hash)
  printf '%s/.local/backups/verified/%s-%s.marker\n' "$M5_REPO_ROOT" "${BOARD_KEY:-unknown}" "$identifier"
}

require_port_access() {
  local resolved_port

  resolved_port=$(readlink -f -- "$M5_PORT")
  [[ $resolved_port == /dev/ttyACM* || $resolved_port == /dev/ttyUSB* ]] || die "想定外のデバイスノードです: $resolved_port"
  [[ -r $resolved_port && -w $resolved_port ]] || die "$resolved_port を読み書きできません。./scripts/grant-port-access.sh を実行してください。"
  printf '%s\n' "$resolved_port"
}

assert_exact_git_checkout() {
  local directory=$1
  local expected_commit=$2
  local actual_commit

  [[ -d $directory/.git ]] || die "Git checkoutが見つかりません: $directory"
  actual_commit=$(git -C "$directory" rev-parse HEAD)
  [[ $actual_commit == "$expected_commit" ]] || die "$directory のHEADが固定値と一致しません: $actual_commit"
}
