#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Cardputer向けコミュニティFWを config/cardputer-firmware.tsv の固定版で取得し、
# sha256を検証して .local/firmware-cache/cardputer/ に置く。
# 使用方法:
#   fetch-cardputer-firmware.sh            全件取得
#   fetch-cardputer-firmware.sh <key>      指定キーだけ取得（launcher/bruce/gamestation…）
#   fetch-cardputer-firmware.sh --list     カタログを一覧表示（ダウンロードなし）

CATALOG="$M5_REPO_ROOT/config/cardputer-firmware.tsv"
CACHE_DIR="$M5_REPO_ROOT/.local/firmware-cache/cardputer"

[[ -f $CATALOG ]] || die "カタログが見つかりません: $CATALOG"

want=""
list_only=false
case "${1:-}" in
  --list) list_only=true ;;
  "") ;;
  -*) die "使用方法: $0 [<key>|--list]" ;;
  *) want=$1 ;;
esac

if [[ $list_only == true ]]; then
  printf '%-13s %-24s %-8s %-7s %s\n' KEY NAME VERSION OFFSET FILENAME
  while IFS=$'\t' read -r key name version offset filename sha url; do
    [[ -z $key || $key == \#* ]] && continue
    printf '%-13s %-24s %-8s %-7s %s\n' "$key" "$name" "$version" "$offset" "$filename"
  done < "$CATALOG"
  exit 0
fi

require_command curl
require_command sha256sum
mkdir -p "$CACHE_DIR"

matched=false
while IFS=$'\t' read -r key name version offset filename sha url; do
  [[ -z $key || $key == \#* ]] && continue
  [[ -n $want && $want != "$key" ]] && continue
  matched=true

  dest="$CACHE_DIR/$filename"
  if [[ -f $dest ]] && printf '%s  %s\n' "$sha" "$dest" | sha256sum -c --status 2> /dev/null; then
    log "取得済み(sha一致): $name $version -> $filename"
    continue
  fi

  log "ダウンロード: $name $version"
  tmp="$dest.part"
  rm -f -- "$tmp"
  curl -fL --retry 3 --proto '=https' -o "$tmp" "$url" || die "ダウンロード失敗: $url"
  if ! printf '%s  %s\n' "$sha" "$tmp" | sha256sum -c --status; then
    rm -f -- "$tmp"
    die "sha256が固定値と一致しません: $filename（カタログの版/URLを確認）。"
  fi
  mv -f -- "$tmp" "$dest"
  log "OK: $dest"
done < "$CATALOG"

[[ $matched == true ]] || die "カタログに一致するキーがありません: ${want:-<all>}"
log "完了。書込みは task cardputer:fw:flash:run FW=<key> で行います。"
