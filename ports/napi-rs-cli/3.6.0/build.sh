#!/bin/sh
set -e

# 纯 JS/TS 产物（@napi-rs/cli）：npm tgz 已含 dist/，打 patch 后即可发布；无 addon 构建 / prebuild / 签名。
# 上游为 npm 包 @napi-rs/cli@3.6.0（workspace 根仓库见 https://github.com/napi-rs/napi-rs ）

# 准备编译环境（与其他 port 对齐；本包实际仅需解压与 patch，工具链检查在部分桌面环境可能较吵）
source ../../../build-env.sh
source ../../../setup-env.sh

PKG_NAME="napi-rs-cli"
UPSTREAM_VERSION="3.6.0"
# 与上游 scoped 包名对应的 tgz 文件名：cli-<ver>.tgz
NPM_TARBALL="cli-${UPSTREAM_VERSION}.tgz"
NPM_TARBALL_URL="https://registry.npmjs.org/@napi-rs/cli/-/${NPM_TARBALL}"
WORKDIR="${PKG_NAME}-${UPSTREAM_VERSION}"

strip_cr_to_lf() {
    f=$1
    [ -f "$f" ] || return 0
    if command -v tr >/dev/null 2>&1; then
        tr -d '\r' <"$f" >"$f.be-lf.tmp" && mv "$f.be-lf.tmp" "$f"
        return 0
    fi
    CR=$(printf '\r')
    if command -v sed >/dev/null 2>&1; then
        sed "s/${CR}\$//" <"$f" >"$f.be-lf.tmp" && mv "$f.be-lf.tmp" "$f"
        return 0
    fi
    if command -v awk >/dev/null 2>&1; then
        awk '{ sub(/\r$/,""); print }' <"$f" >"$f.be-lf.tmp" && mv "$f.be-lf.tmp" "$f"
        return 0
    fi
    printf '%s\n' "[napi-rs-cli] ERROR: 无法去除 CRLF（需要 tr、sed 或 awk 之一）" >&2
    return 1
}

rm -rf "${WORKDIR}"
curl -fsSL "${NPM_TARBALL_URL}" -o "${NPM_TARBALL}"
tar -zxf "${NPM_TARBALL}"
mv package "${WORKDIR}"
rm -f "${NPM_TARBALL}"

cd "${WORKDIR}"
strip_cr_to_lf package.json
patch -p1 < ../patchs/0001-update-package-json.patch
patch -p1 < ../patchs/0002-template-archive-fallback.patch
cd ..
