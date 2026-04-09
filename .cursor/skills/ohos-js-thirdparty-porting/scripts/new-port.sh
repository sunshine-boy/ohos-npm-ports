#!/usr/bin/env bash
# 在 ohos-npm-ports 仓库根目录（含 ports/ 与 setup-*.sh）下执行，或指定 --output-root。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TPL="${SKILL_ROOT}/templates"

usage() {
  cat <<'USAGE'
用法: new-port.sh [选项] <pkg> <upstream-version>

  <pkg>              npm 短包名，如 bufferutil、sqlite3（不含 scope）
  <upstream-version> 上游版本号，如 4.0.9、5.1.7（与 ports/<pkg>/<ver> 目录一致）

选项:
  --output-root DIR   含 ports/ 的仓库根目录（默认: 当前目录）
  --mode MODE         light | framework（默认: light）
  --src-dir NAME      解压后顶层目录名（默认: <pkg>-<upstream-version>）
  --npm-name NAME     registry 包名，默认同 <pkg>（若与 GitHub 仓库名不一致时再设）
  --port-rev N        适配修订号，写入 patchs/README（默认: 1）
  --archive-url URL   上游源码 tarball 直链（不设则 build.sh 内为 TODO）
  --release-base-url URL   framework: GitHub release 目录 URL（到 /vX.Y.Z 为止）
  --asset-prefix STR       framework: release 资源名前缀，如 sqlite3-v5.1.7-napi-v6
  --release-binary-rel PATH framework: 解压后 .node 相对路径，如 build/Release/node_sqlite3.node
  --platforms 'a b c'      framework: 空格分隔的平台目录名列表
  --tarball NAME      下载保存的源码包文件名（默认: <src-dir>.tar.gz）
  -h, --help          显示本说明

选项与 <pkg> <version> 顺序任意。

示例:
  cd /path/to/ohos-npm-ports
  ./.cursor/skills/ohos-js-thirdparty-porting/scripts/new-port.sh bufferutil 4.0.9 \\
    --archive-url 'https://github.com/websockets/bufferutil/archive/refs/tags/v4.0.9.tar.gz'

  ./scripts/new-port.sh sqlite3 5.1.7 --mode framework \\
    --src-dir node-sqlite3-5.1.7 \\
    --archive-url 'https://github.com/TryGhost/node-sqlite3/archive/refs/tags/v5.1.7.tar.gz' \\
    --release-base-url 'https://github.com/TryGhost/node-sqlite3/releases/download/v5.1.7' \\
    --asset-prefix 'sqlite3-v5.1.7-napi-v6' \\
    --release-binary-rel 'build/Release/node_sqlite3.node' \\
    --platforms 'darwin-arm64 darwin-x64 linux-arm64 linux-x64 linuxmusl-arm64 linuxmusl-x64 win32-ia32 win32-x64'
USAGE
}

OUTPUT_ROOT="$(pwd)"
MODE="light"
SRC_DIR=""
NPM_NAME=""
PORT_REV="1"
ARCHIVE_URL=""
RELEASE_BASE_URL=""
ASSET_PREFIX=""
RELEASE_BINARY_REL="build/Release/TODO.node"
PLATFORMS="darwin-arm64 darwin-x64 linux-arm64 linux-x64 win32-ia32 win32-x64"
TARBALL_BASENAME=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root) OUTPUT_ROOT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --src-dir) SRC_DIR="$2"; shift 2 ;;
    --npm-name) NPM_NAME="$2"; shift 2 ;;
    --port-rev) PORT_REV="$2"; shift 2 ;;
    --archive-url) ARCHIVE_URL="$2"; shift 2 ;;
    --release-base-url) RELEASE_BASE_URL="$2"; shift 2 ;;
    --asset-prefix) ASSET_PREFIX="$2"; shift 2 ;;
    --release-binary-rel) RELEASE_BINARY_REL="$2"; shift 2 ;;
    --platforms) PLATFORMS="$2"; shift 2 ;;
    --tarball) TARBALL_BASENAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "未知选项: $1" >&2
      usage >&2
      exit 1
      ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
  usage >&2
  exit 1
fi

PKG="${POSITIONAL[0]}"
UPSTREAM_VERSION="${POSITIONAL[1]}"
SRC_DIR="${SRC_DIR:-${PKG}-${UPSTREAM_VERSION}}"
NPM_NAME="${NPM_NAME:-${PKG}}"
TARBALL_BASENAME="${TARBALL_BASENAME:-${SRC_DIR}.tar.gz}"

if [[ "${MODE}" != "light" && "${MODE}" != "framework" ]]; then
  echo "--mode 必须是 light 或 framework" >&2
  exit 1
fi

ARCHIVE_URL="${ARCHIVE_URL:-https://TODO-set-archive-url/archive-or-tag-v${UPSTREAM_VERSION}.tar.gz}"
if [[ "${MODE}" == "framework" ]]; then
  RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://TODO-github.com/OWNER/REPO/releases/download/v${UPSTREAM_VERSION}}"
  ASSET_PREFIX="${ASSET_PREFIX:-${PKG}-v${UPSTREAM_VERSION}-napi-v6}"
fi

PORT_DIR="${OUTPUT_ROOT}/ports/${PKG}/${UPSTREAM_VERSION}"
PATCH_DIR="${PORT_DIR}/patchs"

mkdir -p "${PATCH_DIR}"

subst() {
  sed \
    -e "s|@PKG@|${PKG}|g" \
    -e "s|@UPSTREAM_VERSION@|${UPSTREAM_VERSION}|g" \
    -e "s|@SRC_DIR@|${SRC_DIR}|g" \
    -e "s|@TARBALL_BASENAME@|${TARBALL_BASENAME}|g" \
    -e "s|@NPM_PKG@|${NPM_NAME}|g" \
    -e "s|@PORT_REV@|${PORT_REV}|g" \
    -e "s|@ARCHIVE_URL@|${ARCHIVE_URL}|g" \
    -e "s|@RELEASE_BASE_URL@|${RELEASE_BASE_URL}|g" \
    -e "s|@ASSET_PREFIX@|${ASSET_PREFIX}|g" \
    -e "s|@RELEASE_BINARY_REL@|${RELEASE_BINARY_REL}|g" \
    -e "s|@PLATFORMS@|${PLATFORMS}|g"
}

if [[ "${MODE}" == "light" ]]; then
  subst < "${TPL}/build-light.sh.tpl" > "${PORT_DIR}/build.sh"
else
  subst < "${TPL}/build-framework.sh.tpl" > "${PORT_DIR}/build.sh"
fi

subst < "${TPL}/publish.sh.tpl" > "${PORT_DIR}/publish.sh"
subst < "${TPL}/patchs-README.md.tpl" > "${PATCH_DIR}/README.md"

chmod +x "${PORT_DIR}/build.sh" "${PORT_DIR}/publish.sh"

echo "已生成:"
echo "  ${PORT_DIR}/build.sh"
echo "  ${PORT_DIR}/publish.sh"
echo "  ${PATCH_DIR}/README.md"
echo ""
echo "下一步: 按 patchs/README.md 制作 0001-*.patch，补全 build.sh 内 TODO（轻量模式需写各平台 rename）。"
