#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${ROOT_DIR}/.local/m5burner"
BINARY="${TARGET_DIR}/bin/m5burner"

if [[ ! -f "${BINARY}" ]]; then
  echo "M5Burner が見つかりません。自動セットアップを実行します..."
  "${SCRIPT_DIR}/setup-m5burner.sh"
fi

# dialout / uucp グループチェックの親切案内
if ! groups 2> /dev/null | grep -E -q 'dialout|uucp'; then
  echo "【注意】ユーザーが dialout または uucp グループに所属していません。"
  echo "シリアルポート(/dev/ttyACM0)書き込みエラーになる場合は以下を実行してください:"
  echo "  sudo groupadd dialout 2>/dev/null || true"
  echo "  sudo usermod -a -G dialout,uucp \$USER"
fi

echo "M5Burner を起動します..."
cd "${TARGET_DIR}"
exec "${BINARY}" --no-sandbox "$@"
