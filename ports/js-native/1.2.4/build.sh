#!/bin/sh
set -e

# 纯 JS 包（js-native）：npm tgz 解压后打 patch 即可，无需 prebuild/签名。
# 上游：js-native@1.2.4（`https://www.npmjs.com/package/js-native`）

# 准备编译环境（相对于 ports/<pkg>/<ver>/ 的路径）
source ../../../build-env.sh
source ../../../setup-env.sh

PKG="js-native"
UPSTREAM_VERSION="1.2.4"
SRC_DIR="package"
ARCHIVE_URL="https://registry.npmjs.org/js-native/-/js-native-1.2.4.tgz"
TARBALL="js-native-1.2.4.tgz"

rm -rf "${SRC_DIR}"
curl -fsSL "${ARCHIVE_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
cd "${SRC_DIR}"
patch -p1 < ../patchs/0001-update-package-json.patch
cd ..
rm -f "${TARBALL}"
