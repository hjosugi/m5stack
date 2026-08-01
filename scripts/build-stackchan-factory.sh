#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command cmake
require_command git
require_command python3

upstream_root="$M5_REPO_ROOT/.local/upstream"
stackchan_root="$upstream_root/StackChan"
firmware_root="$stackchan_root/firmware"
idf_path="$upstream_root/esp-idf"
export IDF_TOOLS_PATH="$M5_REPO_ROOT/.local/espressif"

assert_exact_git_checkout "$stackchan_root" "$STACKCHAN_UPSTREAM_COMMIT"
assert_exact_git_checkout "$idf_path" "$ESP_IDF_COMMIT"
[[ -f $IDF_TOOLS_PATH/idf-env.json ]] || die "ESP-IDFツールが未導入です。先に ./scripts/setup-stackchan-factory.sh を実行してください。"

dependency_total=0
dependency_present=0
while IFS='|' read -r name _url _ref _commit relative_path; do
  [[ -z $name || $name == \#* || $relative_path != */* ]] && continue
  ((dependency_total += 1))
  [[ -d $upstream_root/$relative_path/.git ]] && ((dependency_present += 1))
done < "$M5_REPO_ROOT/config/upstream.lock"

if ((dependency_present == 0)); then
  log "StackChan公式スクリプトで依存ソースを取得します。"
  (cd "$firmware_root" && python3 ./fetch_repos.py)
elif ((dependency_present == dependency_total)); then
  log "取得済みのStackChan依存ソースを検証します。"
else
  die "StackChan依存checkoutが一部だけ存在します。中断した取得内容を確認してから再実行してください。"
fi
"$SCRIPT_DIR/verify-stackchan-upstream.sh"

host_build="$M5_REPO_ROOT/.local/build/stackchan-host-tests"
cmake -S "$firmware_root/tests" -B "$host_build"
cmake --build "$host_build" --parallel
ctest --test-dir "$host_build" --output-on-failure

# export.shはPATHとPython仮想環境を設定する。
# Nix版esptoolのPython依存をESP-IDF専用venvへ混在させない。
unset PYTHONPATH
# Nixのbashはプログラム補完を含まない場合があり、export.shの補完処理では
# completeとCOMP_WORDBREAKSを要求する。環境読込み中だけ安全なstubを用意する。
idf_completion_stub=false
if ! type complete > /dev/null 2>&1; then
  complete() { :; }
  idf_completion_stub=true
fi
COMP_WORDBREAKS=${COMP_WORDBREAKS:-}
set +u
# shellcheck disable=SC1090,SC1091
source "$idf_path/export.sh"
set -u
if [[ $idf_completion_stub == true ]]; then
  unset -f complete
fi

firmware_build=${M5_STACKCHAN_BUILD_DIR:-"$M5_REPO_ROOT/.local/build/stackchan-factory-ja"}
sdkconfig="$firmware_build/sdkconfig"
defaults="$firmware_root/sdkconfig.defaults;$M5_REPO_ROOT/config/stackchan/sdkconfig.defaults.local"
if [[ -n ${M5_STACKCHAN_EXTRA_DEFAULTS:-} ]]; then
  [[ -f $M5_STACKCHAN_EXTRA_DEFAULTS ]] || die "追加sdkconfig defaultsが見つかりません: $M5_STACKCHAN_EXTRA_DEFAULTS"
  defaults="$defaults;$M5_STACKCHAN_EXTRA_DEFAULTS"
fi

idf_extra_args=()
if [[ -n ${M5_STACKCHAN_EXTRA_COMPONENT_DIRS:-} ]]; then
  [[ -d $M5_STACKCHAN_EXTRA_COMPONENT_DIRS ]] || die "追加ESP-IDF componentが見つかりません: $M5_STACKCHAN_EXTRA_COMPONENT_DIRS"
  idf_extra_args+=("-D" "EXTRA_COMPONENT_DIRS=$M5_STACKCHAN_EXTRA_COMPONENT_DIRS")
fi

log "StackChan公式ファームウェア $STACKCHAN_FIRMWARE_VERSION を日本語設定でビルドします。"
(
  cd "$firmware_root"
  idf.py \
    -B "$firmware_build" \
    -D "SDKCONFIG=$sdkconfig" \
    -D "SDKCONFIG_DEFAULTS=$defaults" \
    "${idf_extra_args[@]}" \
    build
)

grep -qx 'CONFIG_LANGUAGE_JA_JP=y' "$sdkconfig" || die "日本語設定が生成sdkconfigへ反映されていません。"
grep -qx '# CONFIG_LANGUAGE_EN_US is not set' "$sdkconfig" || die "英語設定が無効化されていません。"
[[ -s $firmware_build/stack-chan.bin ]] || die "アプリケーションbinが生成されていません。"

log "公式ファームウェアのホストテストとESP32-S3ビルドが完了しました。"
log "成果物: $firmware_build（実機への書込みは行っていません）"
