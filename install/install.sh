#!/usr/bin/env bash
# 把 Trae Auto Checkin 插件安装到 Trae CN IDE（macOS / Linux）
#
# 用法:
#   ./install.sh                                  # 自动查找脚本目录/上级目录中的 vsix
#   ./install.sh ./lihui.trae-auto-checkin-1.0.4.vsix
#   ./install.sh ./lihui.trae-auto-checkin-1.0.4.vsix --no-cli   # 强制使用解压方式
set -euo pipefail

PUBLISHER="LiHui"                                        # 与 Open VSX 命名空间一致
NAME="trae-auto-checkin"
EXT_ID="${PUBLISHER}.${NAME}"
DIR_ID="$(printf '%s' "$EXT_ID" | tr '[:upper:]' '[:lower:]')"   # IDE 扩展目录使用小写 id

step() { printf '\033[36m[install]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[install]\033[0m %s\n' "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSIX=""
NO_CLI=0

for arg in "$@"; do
  case "$arg" in
    --no-cli) NO_CLI=1 ;;
    *) VSIX="$arg" ;;
  esac
done

# ---------- 1. 定位 vsix ----------
if [ -z "$VSIX" ]; then
  VSIX=$(ls -1 "$SCRIPT_DIR"/*trae-auto-checkin-*.vsix "$SCRIPT_DIR"/../*trae-auto-checkin-*.vsix 2>/dev/null | sort -V | tail -n 1 || true)
fi
if [ -z "$VSIX" ] || [ ! -f "$VSIX" ]; then
  echo "找不到 ${EXT_ID}-<version>.vsix，请把 vsix 放到脚本目录，或作为参数传入。" >&2
  exit 1
fi
VSIX="$(cd "$(dirname "$VSIX")" && pwd)/$(basename "$VSIX")"
step "使用插件包: $VSIX"

# ---------- 2. 解析版本与目标目录名 ----------
VSIX_NAME="$(basename "$VSIX")"
VSIX_NAME="${VSIX_NAME%.vsix}"
VERSION="${VSIX_NAME##*-}"
case "$VERSION" in
  ''|*[!0-9.]*) VERSION="0.0.0" ;;
esac
TARGET_DIR_NAME="${DIR_ID}-${VERSION}"

# ---------- 3. 扩展根目录 ----------
EXT_ROOT="$HOME/.trae-cn/extensions"
if [ ! -d "$EXT_ROOT" ]; then
  [ -d "$HOME/.trae/extensions" ] && EXT_ROOT="$HOME/.trae/extensions"
fi
mkdir -p "$EXT_ROOT"
step "扩展目录: $EXT_ROOT"

# ---------- 4. 清理历史版本 ----------
shopt -s nullglob
for d in "$EXT_ROOT"/*trae-auto-checkin-*; do
  [ -d "$d" ] || continue
  [ "$(basename "$d")" = "$TARGET_DIR_NAME" ] && continue
  step "删除历史版本: $(basename "$d")"
  rm -rf "$d"
done

# ---------- 5. 查找 Trae CN 命令行工具 ----------
CLI=""
if [ "$NO_CLI" -eq 0 ]; then
  for c in \
    "/Applications/Trae CN.app/Contents/Resources/app/bin/trae-cn" \
    "$HOME/Applications/Trae CN.app/Contents/Resources/app/bin/trae-cn" \
    "/Applications/Trae.app/Contents/Resources/app/bin/trae"; do
    [ -x "$c" ] && CLI="$c" && break
  done
  if [ -z "$CLI" ] && command -v trae-cn >/dev/null 2>&1; then
    CLI="$(command -v trae-cn)"
  fi
fi

# ---------- 6. 安装 ----------
if [ -n "$CLI" ]; then
  step "使用 Trae 命令行安装: $CLI"
  if "$CLI" --install-extension "$VSIX" --force; then
    ok "安装完成（$TARGET_DIR_NAME）。请重启 Trae CN IDE 生效。"
    exit 0
  fi
  echo "[install] 命令行安装失败，改用解压方式安装。" >&2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
unzip -q "$VSIX" -d "$TMP_DIR"
[ -d "$TMP_DIR/extension" ] || { echo "vsix 内缺少 extension 目录，安装包可能损坏。" >&2; exit 1; }
rm -rf "$EXT_ROOT/$TARGET_DIR_NAME"
mv "$TMP_DIR/extension" "$EXT_ROOT/$TARGET_DIR_NAME"
ok "已解压安装到: $EXT_ROOT/$TARGET_DIR_NAME"
ok '安装完成。请重启 Trae CN IDE，命令面板搜索 “Trae Checkin: 立即签到” 即可使用。'
