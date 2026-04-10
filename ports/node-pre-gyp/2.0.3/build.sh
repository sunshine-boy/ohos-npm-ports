#!/bin/sh
set -e

# 纯 JS 工具包：无原生 .node；为 OpenHarmony 扩展 platform 解析（versioning.evaluate）。
# 上游：@mapbox/node-pre-gyp@2.0.3 — https://www.npmjs.com/package/@mapbox/node-pre-gyp

source ../../../build-env.sh
source ../../../setup-env.sh

PKG_NAME_UNSCOPED="node-pre-gyp"
UPSTREAM_VERSION="2.0.3"
# 与 npm 上 scoped 包 tarball 路径一致：@mapbox/node-pre-gyp/-/node-pre-gyp-<ver>.tgz
UPSTREAM_TARBALL_URL="https://registry.npmjs.org/@mapbox/node-pre-gyp/-/node-pre-gyp-${UPSTREAM_VERSION}.tgz"
SRC_DIR="package"
TARBALL="mapbox-${PKG_NAME_UNSCOPED}-${UPSTREAM_VERSION}.tgz"

rm -rf "${SRC_DIR}"
curl -fsSL "${UPSTREAM_TARBALL_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
cd "${SRC_DIR}"

patch -p1 < ../patchs/0001-openharmony-platform.patch
patch -p1 < ../patchs/0002-gyp-env-sanitize-ohos-llvm.patch

cd ..
rm -f "${TARBALL}"
