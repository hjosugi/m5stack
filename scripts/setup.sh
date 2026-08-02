#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command arduino-cli
require_command git
configure_arduino_env

log "M5Stack Board Managerの索引を更新します。"
arduino_cli core update-index
arduino_cli core install "m5stack:esp32@$M5_CORE_VERSION"

while IFS=$'\t' read -r key _model fqbn _chip _flash_bytes; do
  [[ -z $key || $key == \#* ]] && continue
  arduino_cli board details --fqbn "$fqbn" > /dev/null || die "Board ManagerにFQBNがありません: $fqbn"
done < "$M5_REPO_ROOT/config/boards.tsv"

install_library() {
  local name=$1
  local version=$2
  log "$name $version を導入します。"
  arduino_cli lib install --no-deps "$name@$version"
}

# 依存の自動解決で将来版が混ざらないよう、すべて個別に固定する。
install_library M5GFX "$M5GFX_VERSION"
install_library M5Unified "$M5UNIFIED_VERSION"
install_library M5Cardputer "$M5CARDPUTER_VERSION"
install_library ArduinoJson "$ARDUINOJSON_VERSION"
install_library ArduinoWebsockets "$ARDUINOWEBSOCKETS_VERSION"
install_library IRremoteESP8266 "$IRREMOTEESP8266_VERSION"
install_library M5Unit-NFC "$M5UNIT_NFC_VERSION"

bsp_dir="$ARDUINO_DIRECTORIES_USER/libraries/StackChan-BSP"
if [[ ! -e $bsp_dir ]]; then
  git clone https://github.com/m5stack/StackChan-BSP.git "$bsp_dir"
elif [[ ! -d $bsp_dir/.git ]]; then
  die "$bsp_dir はGit checkoutではありません。内容を退避してから再実行してください。"
elif [[ -n $(git -C "$bsp_dir" status --porcelain) ]]; then
  die "$bsp_dir にローカル変更があります。内容を退避してから再実行してください。"
fi
git -C "$bsp_dir" fetch origin "$STACKCHAN_BSP_COMMIT"
git -C "$bsp_dir" checkout --detach "$STACKCHAN_BSP_COMMIT"
assert_exact_git_checkout "$bsp_dir" "$STACKCHAN_BSP_COMMIT"

log "導入済みCore:"
arduino_cli core list | awk 'NR == 1 || $1 == "m5stack:esp32"'
log "導入済みM5ライブラリ:"
arduino_cli lib list | awk 'NR == 1 || $1 ~ /^(M5|ArduinoWebsockets|IRremoteESP8266|StackChan-BSP)/'
log "Arduino環境の固定版セットアップが完了しました。実機は操作していません。"
