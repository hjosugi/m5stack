#!/usr/bin/env bash
set -euo pipefail

# setup-wizard.sh の get_key/set_key/ask を source して単体テストする。
# 対話フローは main() に隔離してあるので、source しても実行されない。

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# 関数だけ読み込む（main は BASH_SOURCE != $0 なので走らない）。
# shellcheck source=../scripts/setup-wizard.sh
source "$REPO_ROOT/scripts/setup-wizard.sh"

firm_env="$TEST_ROOT/.env"
: > "$firm_env"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# ask を任意の入力で呼ぶ。set -e で落ちないことも確認するため rc を拾う。
run_ask() {
  local input=$1
  shift
  local rc
  set +e
  ask "$@" > /dev/null 2>&1 <<< "$input"
  rc=$?
  set -e
  [[ $rc == 0 ]] || fail "ask が非0を返した (args: $*, rc=$rc)"
}

# --- get_key / set_key ラウンドトリップ ---
set_key FOO bar
[[ $(get_key FOO) == bar ]] || fail "set_key/get_key roundtrip"
set_key FOO baz # 既存キーは重複せず置換される
[[ $(get_key FOO) == baz ]] || fail "set_key 置換"
[[ $(grep -c '^FOO=' "$firm_env") == 1 ]] || fail "FOO が重複した"

# --- 未設定 + 値入力 → セットされる ---
: > "$firm_env"
run_ask 'newval' WIFI_SSID "SSID"
[[ $(get_key WIFI_SSID) == newval ]] || fail "未設定に値を入れられない"

# --- 未設定 + 空Enter → 何も書かない（スキップ） ---
: > "$firm_env"
run_ask '' WIFI_SSID "SSID"
[[ -z $(get_key WIFI_SSID) ]] || fail "未設定の空Enterで値が入った"

# --- 設定済み + 空Enter → 現状維持 ---
set_key LOCAL_LLM_MODEL "qwen2.5:3b"
run_ask '' LOCAL_LLM_MODEL "モデル"
[[ $(get_key LOCAL_LLM_MODEL) == "qwen2.5:3b" ]] || fail "空Enterで維持されない"

# --- 設定済み + 新しい正しい値 → 上書き ---
run_ask 'llama3.2:3b' LOCAL_LLM_MODEL "モデル"
[[ $(get_key LOCAL_LLM_MODEL) == "llama3.2:3b" ]] || fail "正しい値で上書きされない"

# --- 不正な値 → 上書きしない（その後 空Enterで維持） ---
set_key MONTHLY_BUDGET_USD 5
# "y"(不正) の後に 空Enter を与える → 5 のまま
run_ask $'y\n' MONTHLY_BUDGET_USD "予算" '^[0-9]+(\.[0-9]+)?$'
[[ $(get_key MONTHLY_BUDGET_USD) == 5 ]] || fail "不正値で上書きされた"

# --- 不正 → 正しい値 の順で最終的に採用 ---
run_ask $'abc\n7.5\n' MONTHLY_BUDGET_USD "予算" '^[0-9]+(\.[0-9]+)?$'
[[ $(get_key MONTHLY_BUDGET_USD) == 7.5 ]] || fail "再入力の正しい値が採用されない"

# --- 秘密: 設定済み + "Y"(このまま) → 変更しない ---
set_key DEEPSEEK_API "sk-original"
run_ask 'Y' DEEPSEEK_API "APIキー" '^[A-Za-z0-9._-]+$' secret
[[ $(get_key DEEPSEEK_API) == "sk-original" ]] || fail "秘密Yで維持されない"

# --- 秘密: 設定済み + "n" → 新しい値を入力して上書き ---
run_ask $'n\nsk-newkey' DEEPSEEK_API "APIキー" '^[A-Za-z0-9._-]+$' secret
[[ $(get_key DEEPSEEK_API) == "sk-newkey" ]] || fail "秘密nで上書きされない"

# --- 秘密: 不正な新値は上書きしない（nの後に不正→空Enterで維持） ---
set_key DEEPSEEK_API "sk-keepme"
run_ask $'n\nbad key with space\n' DEEPSEEK_API "APIキー" '^[A-Za-z0-9._-]+$' secret
[[ $(get_key DEEPSEEK_API) == "sk-keepme" ]] || fail "秘密の不正値で上書きされた"

printf 'setup-wizard tests: OK\n'
