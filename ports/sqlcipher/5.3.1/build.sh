#!/bin/sh
set -e

# 原生 addon（Node-API + SQLCipher）：与 ports/sqlite3 类似，改为 node-gyp-build + prebuildify；
# 上游：https://github.com/journeyapps/node-sqlcipher 标签 v5.3.1（npm 包 @journeyapps/sqlcipher）
# 其他平台二进制从上游 S3 拉取 napi-v6-*（与上游发布一致）；OpenHarmony arm64 在本机 prebuildify 产出并可选签名。

source ../../../build-env.sh
source ../../../setup-env.sh

PKG_DIR="node-sqlcipher-5.3.1"
UPSTREAM_VERSION="5.3.1"
TARBALL="${PKG_DIR}.tar.gz"
UPSTREAM_URL="https://github.com/journeyapps/node-sqlcipher/archive/refs/tags/v${UPSTREAM_VERSION}.tar.gz"
NPM_SCOPE="tetcl"
PREBUILD_NODE_NAME="@${NPM_SCOPE}+sqlcipher.node"
OH_PREBUILD_DIR="prebuilds/openharmony-arm64"
# 上游 node-pre-gyp 产物仍为 node_sqlite3.node（模块名未改）
UPSTREAM_S3_BASE="https://journeyapps-node-binary.s3.amazonaws.com/@journeyapps/sqlcipher/v${UPSTREAM_VERSION}"

rm -rf "${PKG_DIR}"
curl -fsSL "${UPSTREAM_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
rm -f "${TARBALL}"

cd "${PKG_DIR}"

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
    printf '%s\n' "[sqlcipher] ERROR: 无法去除 CRLF（需要 tr、sed 或 awk 之一）" >&2
    return 1
}
# Windows / git autocrlf 可能把 package.json 变成 CRLF，patch 会整段匹配失败；打补丁前统一去掉 \r
for f in package.json binding.gyp lib/sqlite3-binding.js lib/sqlite3.js sqlite3.js deps/sqlite3.gyp; do
    strip_cr_to_lf "$f"
done

patch -p1 < ../patchs/0001-change-prebuild-framework.patch
patch -p1 < ../patchs/0002-linux-openssl-libdir.patch

# 上游 Linux 分支仅写 -lcrypto，依赖默认库路径；鸿蒙/NDK 需在 sysroot 的 usr/lib/<triple> 下才有 libcrypto。
# 可通过环境变量 SQLCIPHER_OPENSSL_LIBDIR 覆盖；未设置时按常见 OHOS_SDK 布局探测。
OHOS_ROOT="${OHOS_SDK_OHOS_DIR:-/opt/ohos-sdk/ohos}"
if [ -z "${SQLCIPHER_OPENSSL_LIBDIR:-}" ]; then
    for d in \
        "${OHOS_ROOT}/native/sysroot/usr/lib/aarch64-linux-ohos" \
        "${OHOS_ROOT}/native/sysroot/usr/lib/aarch64-unknown-linux-ohos" \
        "${OHOS_ROOT}/native/sysroot/usr/lib/arm-linux-ohos" \
        "${OHOS_ROOT}/native/llvm/lib/aarch64-linux-ohos"; do
        if [ -f "${d}/libcrypto.so" ] || [ -f "${d}/libcrypto.a" ]; then
            SQLCIPHER_OPENSSL_LIBDIR="${d}"
            break
        fi
    done
fi
SQLCIPHER_OPENSSL_LIBDIR="${SQLCIPHER_OPENSSL_LIBDIR:-.}"
export SQLCIPHER_OPENSSL_LIBDIR
if [ "${SQLCIPHER_OPENSSL_LIBDIR}" != "." ]; then
    export LDFLAGS="${LDFLAGS:-} -L${SQLCIPHER_OPENSSL_LIBDIR} -Wl,-rpath-link,${SQLCIPHER_OPENSSL_LIBDIR}"
fi

npm install
npm run prebuild

if [ -f "./${OH_PREBUILD_DIR}/node_sqlite3.node" ] && [ ! -f "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" ]; then
    mv "./${OH_PREBUILD_DIR}/node_sqlite3.node" "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}"
fi

if command -v binary-sign-tool >/dev/null 2>&1 && [ -f "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" ]; then
    binary-sign-tool sign \
        -inFile "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" \
        -outFile "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" \
        -selfSign 1
fi

# 上游公开的二进制（N-API v6）；无 linux-arm64 / musl 等变体时不拉取
for platform in darwin-arm64 darwin-x64 linux-x64 win32-ia32 win32-x64; do
    asset="napi-v6-${platform}"
    curl -fsSL "${UPSTREAM_S3_BASE}/${asset}.tar.gz" -o "${asset}.tar.gz"
    tar -zxf "${asset}.tar.gz"
    mkdir -p "./prebuilds/${platform}"
    cp "${asset}/node_sqlite3.node" "./prebuilds/${platform}/${PREBUILD_NODE_NAME}"
    rm -rf "${asset}" "${asset}.tar.gz"
done

cd ..
