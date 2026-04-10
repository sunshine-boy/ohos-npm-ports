#!/bin/sh
set -e

# 框架模式：bindings → node-gyp-build、prebuild → prebuildify 等；多平台从 GitHub Release 拉取。
# 生成后请核对：ARCHIVE_URL、RELEASE_BASE_URL、PLATFORMS、ASSET_PREFIX、RELEASE_BINARY_REL、patch。

source ../../../setup-tools.sh
source ../../../setup-env.sh

PKG="@PKG@"
UPSTREAM_VERSION="@UPSTREAM_VERSION@"
SRC_DIR="@SRC_DIR@"
ARCHIVE_URL="@ARCHIVE_URL@"
RELEASE_BASE_URL="@RELEASE_BASE_URL@"
ASSET_PREFIX="@ASSET_PREFIX@"
RELEASE_BINARY_REL="@RELEASE_BINARY_REL@"

TARBALL="@TARBALL_BASENAME@"
curl -fsSL "${ARCHIVE_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
cd "${SRC_DIR}"
patch -p1 < ../patchs/0001-change-prebuild-framework.patch

npm install
npm run prebuild

binary-sign-tool sign \
  -inFile "./prebuilds/openharmony-arm64/@ohos-npm-ports+${PKG}.node" \
  -outFile "./prebuilds/openharmony-arm64/@ohos-npm-ports+${PKG}.node" \
  -selfSign 1

base_url="${RELEASE_BASE_URL}"
platforms="@PLATFORMS@"
for platform in ${platforms}; do
  asset_name="${ASSET_PREFIX}-${platform}"
  curl -fsSL "${base_url}/${asset_name}.tar.gz" -o "${asset_name}.tar.gz"
  mkdir "${asset_name}"
  tar -zxf "${asset_name}.tar.gz" -C "${asset_name}"
  mkdir -p "./prebuilds/${platform}"
  cp "./${asset_name}/${RELEASE_BINARY_REL}" "./prebuilds/${platform}/@ohos-npm-ports+${PKG}.node"
done

# TODO: 若需区分 linux glibc/musl，参考 sqlite3 port：下载 linuxmusl-* 后 mv 到对应目录并重命名为 .glibc.node / .musl.node

rm -rf "./${ASSET_PREFIX}"-*
