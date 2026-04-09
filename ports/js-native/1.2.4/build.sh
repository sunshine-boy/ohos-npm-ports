#!/bin/sh
set -e

# 纯 JS 包（js-native）：npm tgz 解压后打 patch 即可，无需 prebuild/签名。
# 上游：js-native@1.2.4（`https://www.npmjs.com/package/js-native`）

# 准备编译环境（相对于 ports/<pkg>/<ver>/ 的路径）
source ../../../build-env.sh
source ../../../setup-env.sh

# 可变项
PKG_NAME="js-native"
UPSTREAM_VERSION="1.2.4"
PORT_REV="1"
UPSTREAM_TARBALL_URL="https://registry.npmjs.org/js-native/-/js-native-1.2.4.tgz"
UPSTREAM_PREBUILDS_SOURCE="https://registry.npmjs.org/js-native/-/js-native-1.2.4.tgz"
OH_NODE_PATH="prebuilds/openharmony-arm64"
# npm registry tgz 解压后目录名固定为 package/，不是包名
SRC_DIR="package"
TARBALL="${PKG_NAME}-${UPSTREAM_VERSION}.tgz"

# 下载上游 tarball → 解压 → 打 patch
rm -rf "${SRC_DIR}"
curl -fsSL "${UPSTREAM_TARBALL_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
cd "${SRC_DIR}"
patch -p1 < ../patchs/0001-update-package-json.patch
cd ..
rm -f "${TARBALL}"
