#!/bin/sh
set -e

# 原生 addon（nan + statvfs）：node-gyp-build + prebuildify；与仓库内 electron-active-window 模式一致。
# 发布 scope：@tetcl（与 js-native 等一致；CI 需 NPM_TOKEN 具备该组织发布权限）
# 上游：diskusage@1.2.0 — https://www.npmjs.com/package/diskusage
# 上游 npm 包无 prebuilds/，仅在本机构建 OpenHarmony arm64 预构建并签名；其他平台需自行扩展 prebuildify 矩阵或从别处合并。

# 准备编译环境
source ../../../build-env.sh
source ../../../setup-env.sh

PKG_NAME="diskusage"
UPSTREAM_VERSION="1.2.0"
SRC_DIR="package"
UPSTREAM_TARBALL_URL="https://registry.npmjs.org/${PKG_NAME}/-/${PKG_NAME}-${UPSTREAM_VERSION}.tgz"
TARBALL="${PKG_NAME}-${UPSTREAM_VERSION}.tgz"
NPM_SCOPE="tetcl"
PREBUILD_NODE_NAME="@${NPM_SCOPE}+${PKG_NAME}.node"
OH_PREBUILD_DIR="prebuilds/openharmony-arm64"

# 准备源码
rm -rf "${SRC_DIR}"
curl -fsSL "${UPSTREAM_TARBALL_URL}" -o "${TARBALL}"
tar -zxf "${TARBALL}"
cd "${SRC_DIR}"

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
    printf '%s\n' "[diskusage] ERROR: 无法去除 CRLF（需要 tr、sed 或 awk 之一）" >&2
    return 1
}
for f in package.json fallback.js binding.gyp; do
    strip_cr_to_lf "$f"
done

patch -p1 < ../patchs/0001-ohos-port-node-gyp-build.patch

# 构建 addon（prebuildify --target 与 build-env 中 OpenHarmony Node 主版本对齐）
npm install
npm run prebuild

if [ -f "./${OH_PREBUILD_DIR}/diskusage.node" ] && [ ! -f "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" ]; then
    mv "./${OH_PREBUILD_DIR}/diskusage.node" "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}"
fi

# 代码签名
if command -v binary-sign-tool >/dev/null 2>&1 && [ -f "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" ]; then
    binary-sign-tool sign \
        -inFile "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" \
        -outFile "./${OH_PREBUILD_DIR}/${PREBUILD_NODE_NAME}" \
        -selfSign 1
fi

# 上游当前无 prebuilds/；若日后 npm 包携带多平台预构建，可在此合并并重命名为 PREBUILD_NODE_NAME
MERGE_STAGING="../.diskusage-merge-prebuilds-$$"
rm -rf "${MERGE_STAGING}"
mkdir "${MERGE_STAGING}"
curl -fsSL "${UPSTREAM_TARBALL_URL}" -o "${MERGE_STAGING}/${TARBALL}"
tar -zxf "${MERGE_STAGING}/${TARBALL}" -C "${MERGE_STAGING}"
if [ -d "${MERGE_STAGING}/package/prebuilds" ]; then
    mkdir -p ./prebuilds
    cp -r "${MERGE_STAGING}/package/prebuilds"/* ./prebuilds/
    if [ -d ./prebuilds ]; then
        for d in ./prebuilds/*; do
            [ -d "$d" ] || continue
            if [ -f "${d}/diskusage.node" ] && [ ! -f "${d}/${PREBUILD_NODE_NAME}" ]; then
                mv "${d}/diskusage.node" "${d}/${PREBUILD_NODE_NAME}"
            fi
        done
    fi
else
    printf '%s\n' "[diskusage] 上游 npm 包无 prebuilds/，跳过多平台合并（仅保留本机构建的 OpenHarmony 等 prebuild）。" >&2
fi
rm -rf "${MERGE_STAGING}"

cd ..
rm -f "${TARBALL}"
