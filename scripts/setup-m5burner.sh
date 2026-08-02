#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_DIR="${ROOT_DIR}/.local/m5burner"
ZIP_FILE="${TARGET_DIR}/M5Burner-v3-beta-linux-x64.zip"
DOWNLOAD_URL="${M5BURNER_URL:-https://m5burner-cdn.m5stack.com/app/M5Burner-v3-beta-linux-x64.zip}"

mkdir -p "${TARGET_DIR}"

if [[ -f "${TARGET_DIR}/M5Burner" && "${1:-}" != "--force" ]]; then
  echo "M5Burner は既にセットアップされています: ${TARGET_DIR}/M5Burner"
  echo "再ダウンロード・更新を行う場合は ./scripts/setup-m5burner.sh --force を実行してください。"
  exit 0
fi

echo "M5Burner をダウンロードしています..."
echo "URL: ${DOWNLOAD_URL}"
curl -L -e "https://docs.m5stack.com/" -o "${ZIP_FILE}" "${DOWNLOAD_URL}"

echo "解凍中..."
unzip -q -o "${ZIP_FILE}" -d "${TARGET_DIR}"

# 解凍先の直下にM5Burner*フォルダが作成された場合の移動処理
SUBDIR="$(find "${TARGET_DIR}" -mindepth 1 -maxdepth 1 -type d -name "M5Burner*" | head -n 1 || true)"
if [[ -n "${SUBDIR}" && -d "${SUBDIR}" ]]; then
  cp -rf "${SUBDIR}"/* "${TARGET_DIR}/" || true
  rm -rf "${SUBDIR}"
fi

if [[ -f "${TARGET_DIR}/M5Burner" ]]; then
  chmod +x "${TARGET_DIR}/M5Burner"
fi

rm -f "${ZIP_FILE}"

echo "M5Burner のセットアップが完了しました: ${TARGET_DIR}/M5Burner"
