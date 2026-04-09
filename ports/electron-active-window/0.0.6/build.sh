#!/bin/sh
set -e

# 原生 addon（C++ Node-API）：node-gyp-build + prebuildify；OpenHarmony 产物命名为 @<scope>+<pkg>.node 并可选签名。
# 上游：electron-active-window@0.0.6 — https://www.npmjs.com/package/electron-active-window
# 发布 scope 与 js-native 一致：@tetcl（CI 需 NPM_TOKEN 具备该组织发布权限）

source ../../../build-env.sh
source ../../../setup-env.sh

PKG_NAME="electron-active-window"
UPSTREAM_VERSION="0.0.6"
NPM_SCOPE="tetcl"
SRC_DIR="package"
UPSTREAM_TARBALL_URL="https://registry.npmjs.org/${PKG_NAME}/-/${PKG_NAME}-${UPSTREAM_VERSION}.tgz"
TARBALL="${PKG_NAME}-${UPSTREAM_VERSION}.tgz"
# prebuildify 仍产出 wm.node（NODE_API_MODULE），需改名为 node-gyp-build 对 scoped 包的约定名
PREBUILD_NODE_NAME="@${NPM_SCOPE}+${PKG_NAME}.node"
OH_PREBUILD_DIR="prebuilds/openharmony-arm64"

rm -rf "${SRC_DIR}"
curl -fsSL "${UPSTREAM_TARBALL_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
cd "${SRC_DIR}"

# 上游部分文件可能为 CRLF，避免 patch 不匹配
perl -pi -e 's/\r$//' package.json index.js binding.gyp cppsrc/main.cpp setup.js 2>/dev/null || true

patch -p1 < ../patchs/0001-change-prebuild-framework.patch

npm install
npm run prebuild

if [ -f "./${OH_PREBUILD_DIR}/wm.node" ] && [ ! -f "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" ]; then
    mv "./${OH_PREBUILD_DIR}/wm.node" "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}"
fi

if command -v binary-sign-tool >/dev/null 2>&1 && [ -f "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" ]; then
    binary-sign-tool sign \
        -inFile "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" \
        -outFile "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" \
        -selfSign 1
fi
cd ..
rm -f "${TARBALL}"
