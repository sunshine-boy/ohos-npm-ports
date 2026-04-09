## 用脚手架起盘

```bash
cd /path/to/ohos-npm-ports
/path/to/skill/scripts/new-port.sh bufferutil 4.0.9 \
  --archive-url 'https://github.com/websockets/bufferutil/archive/refs/tags/v4.0.9.tar.gz'
# 再按 patchs/README.md 生成 0001-update-package-json.patch，并补全 build.sh 里各平台 rename
```

## Skill 验证案例：napi-rs（`@napi-rs/cli`）

[`napi-rs/napi-rs`](https://github.com/napi-rs/napi-rs) 是 **Rust + workspace**，根包 **不发布**；验证本 skill 时应对齐 **npm 已发布** 的 `@napi-rs/cli`（纯 JS CLI，已含 `dist/`），走「纯 JS」流程：拉 **registry tgz** → `patch` 改 `name` / `version` / `repository` / `bugs` → `npm pack --dry-run` / `npm publish`。

本仓库已落一版可运行配方（相对 jspkg 根目录）：

- `ports/napi-rs-cli/3.6.0/build.sh`：下载 `cli-3.6.0.tgz`、重命名目录、`patch`
- `ports/napi-rs-cli/3.6.0/publish.sh`：发布 `@ohos-npm-ports/napi-rs-cli@3.6.0-1`
- `jspkg/setup-tools.sh`、`setup-env.sh`：占位；合并进 ohos-npm-ports 时替换为真脚本

在 `ports/napi-rs-cli/3.6.0` 执行 `./build.sh` 后，于 `napi-rs-cli-3.6.0/` 内执行 `npm pack --dry-run` 应显示包名为 `@ohos-npm-ports/napi-rs-cli@3.6.0-1`。

**说明**：若要让 `napi build` 真正产出 **OpenHarmony** 的 `.node`，需在 Rust 目标三元组、`@napi-rs/cli` 与工具链侧继续开发，不属于「仅改 npm 配方」能单独验证的范围。

## 示例 1：仅修改 package.json（bufferutil 类）

目标：上游已有 prebuild（多平台），我们只新增 OpenHarmony 预构建并合并发布。

最小 patch 思路：
- `package.json`：
  - `name` → `@ohos-npm-ports/bufferutil`
  - `version` → `4.0.9-<rev>`
  - `repository/bugs` 指向维护仓库
- `build.sh`：
  - 拉源码 `v4.0.9`
  - `npm install && npm run prebuild`
  - 签名 `prebuilds/openharmony-arm64/@ohos-npm-ports+bufferutil.node`
  - 从 npm tgz 合并原包 `prebuilds/*`，并重命名各平台 `.node`

## 示例 2：切换 loader + prebuildify（sqlite3 类）

目标：上游的安装/加载与预构建分发机制不适配 OpenHarmony，需要切到本地选择预构建。

关键 patch 点：
- `lib/*binding*.js`：
  - `bindings('xxx.node')` → `node-gyp-build(__dirname + "/../")`
- `package.json`：
  - `dependencies`：移除 `bindings`，加入 `node-gyp-build`
  - `devDependencies`：`prebuild` → `prebuildify`
  - `scripts.install`：`node-gyp-build`
  - `scripts.prebuild`：`prebuildify --napi`
  - `files`：确保包含 `prebuilds/`
- `binding.gyp`：
  - 固定 `NAPI_VERSION=6`（或你选定的版本）
- `build.sh`：
  - OpenHarmony 产物签名
  - 从 GitHub Release（napi-v6）拉其他平台预构建并拷贝到 `prebuilds/<platform>/`
  - linux 平台区分 glibc/musl 并重命名

