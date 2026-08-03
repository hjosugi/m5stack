#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# 実機ごとに .env プロファイルを分けて共存させる。
#   プロファイル: $REPO/.env.<name>        （例: .env.stackchan / .env.cardputer）
#   アクティブ:   $REPO/.env               （既存タスクは全部これを読む）
#   記録:         $REPO/.local/active-target
#
# 切替時は現在のアクティブを元プロファイルへ保存してから差し替えるので、
# init/select/grant 等でアクティブ .env に入れた変更は失われない。
#
# 使用方法:
#   select-target.sh                名前を省略すると現在の状態を表示
#   select-target.sh show           現在の状態を表示
#   select-target.sh list           プロファイル一覧
#   select-target.sh <name>         <name> へ切替（.env.<name> が必要）

ACTIVE_ENV="$M5_REPO_ROOT/.env"
ACTIVE_MARK="$M5_REPO_ROOT/.local/active-target"

profile_path() { printf '%s/.env.%s\n' "$M5_REPO_ROOT" "$1"; }

current_target() {
  [[ -s $ACTIVE_MARK ]] && tr -d '\r\n' < "$ACTIVE_MARK" || printf ''
}

show_model() {
  local file=$1
  [[ -f $file ]] || {
    printf '(なし)'
    return
  }
  local model
  model=$(env_get M5_MODEL "$file")
  printf '%s' "${model:-<未設定>}"
}

list_profiles() {
  local cur
  cur=$(current_target)
  printf '%-12s %-18s %s\n' TARGET MODEL ACTIVE
  shopt -s nullglob
  for file in "$M5_REPO_ROOT"/.env.*; do
    local name=${file##*/.env.}
    [[ $name == example || $name == *.example ]] && continue
    local flag=""
    [[ $name == "$cur" ]] && flag="<= active"
    printf '%-12s %-18s %s\n' "$name" "$(show_model "$file")" "$flag"
  done
  shopt -u nullglob
}

show_status() {
  local cur
  cur=$(current_target)
  if [[ -z $cur ]]; then
    log "アクティブ対象: 未記録（.env の内容: $(show_model "$ACTIVE_ENV")）"
  else
    log "アクティブ対象: $cur （model: $(show_model "$ACTIVE_ENV")）"
  fi
  log "プロファイル:"
  list_profiles
}

action=${1:-show}
case "$action" in
  show)
    show_status
    exit 0
    ;;
  list)
    list_profiles
    exit 0
    ;;
  -*) die "使用方法: $0 [show|list|<name>]" ;;
esac

target=$action
[[ $target =~ ^[a-z0-9_-]+$ ]] || die "対象名は英小文字・数字・_・- のみ: $target"
new_profile=$(profile_path "$target")
[[ -f $new_profile ]] || die "プロファイルがありません: $new_profile"

cur=$(current_target)
if [[ $target == "$cur" ]]; then
  log "既に $target がアクティブです。"
  exit 0
fi

umask 077
# 現在のアクティブを元プロファイルへ保存（編集を失わない）。
if [[ -n $cur && -f $ACTIVE_ENV ]]; then
  cur_profile=$(profile_path "$cur")
  if ! cmp -s "$ACTIVE_ENV" "$cur_profile"; then
    cp -p "$ACTIVE_ENV" "$cur_profile"
    log "現在の .env を保存しました -> .env.$cur"
  fi
fi

cp -p "$new_profile" "$ACTIVE_ENV"
mkdir -p "$(dirname -- "$ACTIVE_MARK")"
printf '%s\n' "$target" > "$ACTIVE_MARK"
log "対象を $target へ切替えました（model: $(show_model "$ACTIVE_ENV")）。"
warn "USB接続中の実機がこの対象と一致しているか確認してください（別機だとタスクは安全に停止します）。"
