#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command git
upstream_root="$M5_REPO_ROOT/.local/upstream"
mkdir -p "$upstream_root"

checkout_exact() {
  local name=$1
  local url=$2
  local commit=$3
  local directory=$4
  local remote_url

  if [[ ! -e $directory ]]; then
    log "$name を取得します。"
    git clone --filter=blob:none --no-checkout "$url" "$directory"
  elif [[ ! -d $directory/.git ]]; then
    die "$directory はGit checkoutではありません。"
  elif [[ -n $(git -C "$directory" status --porcelain) ]]; then
    die "$directory にローカル変更があります。内容を退避してから再実行してください。"
  fi

  remote_url=$(git -C "$directory" remote get-url origin)
  [[ ${remote_url%.git} == "${url%.git}" ]] || die "$name のoriginが固定URLと異なります: $remote_url"
  git -C "$directory" fetch --filter=blob:none origin "$commit"
  git -C "$directory" checkout --detach "$commit"
  assert_exact_git_checkout "$directory" "$commit"
}

checkout_exact StackChan https://github.com/m5stack/StackChan.git "$STACKCHAN_UPSTREAM_COMMIT" "$upstream_root/StackChan"
checkout_exact StackChan-BSP https://github.com/m5stack/StackChan-BSP.git "$STACKCHAN_BSP_COMMIT" "$upstream_root/StackChan-BSP"
checkout_exact ESP-IDF https://github.com/espressif/esp-idf.git "$ESP_IDF_COMMIT" "$upstream_root/esp-idf"

log "ESP-IDFの固定コミットに属するsubmoduleを取得します。"
git -C "$upstream_root/esp-idf" submodule sync --recursive
git -C "$upstream_root/esp-idf" submodule update --init --recursive --depth 1

"$SCRIPT_DIR/verify-stackchan-upstream.sh" --top-level
log "StackChan上流ソースを固定コミットで取得しました。"
