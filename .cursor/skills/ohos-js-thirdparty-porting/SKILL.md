---
name: ohos-js-thirdparty-porting
description: Ports JS third-party libraries to HarmonyOS/OpenHarmony (especially Node-API native addons) following ohos-npm-ports patterns. Use when the user asks to “鸿蒙化适配/移植” an npm package, create a port recipe (build.sh/publish.sh/patchs), generate patches for package.json/binding.gyp/runtime loader, produce OpenHarmony prebuilds, merge multi-platform prebuilds, or prepare a publishable scoped package like @ohos-npm-ports/*.
---

# JS 三方库鸿蒙化适配（ohos-npm-ports 风格）

## 目标

把 npm 三方库（纯 JS 或 Node-API 原生 addon）适配到 HarmonyOS/OpenHarmony，并以 **`@ohos-npm-ports/<pkg>`** 形式发布，产物包含 **OpenHarmony arm64** 预构建文件（必要时合并其他平台 prebuild 一起发）。

你要优先复用两类已验证模式：
- **轻量 patch + 预构建合并**：如 `bufferutil`（改 `package.json` + 构建 OH 预构建 + 签名 + 合并原包 prebuild）
- **替换预构建框架/加载方式**：如 `sqlite3`（`bindings` → `node-gyp-build`，`prebuild` → `prebuildify`，固定 NAPI 版本等）

## 快速判定（先选路径）

1. **是否有原生 addon（.node / binding.gyp / node-gyp / napi / prebuild）？**
   - **否（纯 JS）**：只做包重命名、版本后缀、仓库信息、（如需）改平台/引擎字段；无需 prebuild/签名。
   - **是（Node-API addon）**：按下文 “原生 addon 适配工作流” 执行。
2. **[Rust / napi-rs](https://github.com/napi-rs/napi-rs)**：主仓库多为 **workspace + Cargo**，根 `package.json` 常为 **private**；npm 上实际消费的是子包（如 **`@napi-rs/cli`**，纯 TS 编译产物、无 `.node`）。适配时 **port 已发布的 npm 包** 或具体带 `napi build` 的业务 crate，而不是照抄 `bufferutil` 的 `npm run prebuild`；CLI 侧若需支持 OpenHarmony target，要在 **Rust triple / @napi-rs/cli 逻辑** 上扩展（超出本 skill 的脚本模板范围，见 [examples.md](examples.md) 验证案例）。
3. **上游是否已有可下载的多平台预构建产物？**
   - **有**：推荐“**OH 自己编 + 其他平台从上游拷贝/下载**”合并发布（与示例一致）。
   - **无**：只发布 OH 平台也可，但要确保安装/加载逻辑不会去拉缺失平台产物（通常需要切到 `node-gyp-build` + `prebuildify`）。

## 约定（强制一致）

- **包名**：`@ohos-npm-ports/<name>`
- **版本**：`<upstream-version>-<port-rev>`（例如 `4.0.9-5`、`5.1.7-6`；`port-rev` 从 1 递增）
- **`.node` 文件命名**：`@ohos-npm-ports+<name>.node`
- **OpenHarmony 目录**：`prebuilds/openharmony-arm64/`
- **签名**：对 `prebuilds/openharmony-arm64/*.node` 使用 `binary-sign-tool sign ... -selfSign 1`
- **仓库/bugs 指向**：指向 `ohos-npm-ports/ohos-npm-ports`（或你的目标维护仓库）

## 原生 addon 适配工作流（推荐默认）

### Step A：准备 port 目录骨架（配方）

按版本建立目录（示例）：

```text
ports/<pkg>/<version>/
  build.sh
  publish.sh
  patchs/
    0001-*.patch
    0002-*.patch
```

#### 脚手架（推荐）

在 **ohos-npm-ports 仓库根目录**（存在 `setup-tools.sh`、`setup-env.sh` 与 `ports/`）下执行生成器，可一次性写出 `build.sh`、`publish.sh`、`patchs/README.md`：

```bash
# 轻量模式（对齐 bufferutil）
/path/to/ohos-js-thirdparty-porting/scripts/new-port.sh bufferutil 4.0.9 \
  --archive-url 'https://github.com/websockets/bufferutil/archive/refs/tags/v4.0.9.tar.gz'

# 框架模式（对齐 sqlite3）
/path/to/ohos-js-thirdparty-porting/scripts/new-port.sh sqlite3 5.1.7 --mode framework \
  --src-dir node-sqlite3-5.1.7 \
  --archive-url 'https://github.com/TryGhost/node-sqlite3/archive/refs/tags/v5.1.7.tar.gz' \
  --release-base-url 'https://github.com/TryGhost/node-sqlite3/releases/download/v5.1.7' \
  --asset-prefix 'sqlite3-v5.1.7-napi-v6' \
  --release-binary-rel 'build/Release/node_sqlite3.node' \
  --platforms 'darwin-arm64 darwin-x64 linux-arm64 linux-x64 linuxmusl-arm64 linuxmusl-x64 win32-ia32 win32-x64'
```

生成后仍需：按 `patchs/README.md` 制作 `0001-*.patch`；轻量模式在 `build.sh` 末尾补全各平台 `mv …/@ohos-npm-ports+<pkg>.node`；框架模式按需补 glibc/musl 与清理逻辑。模板与脚本见本 skill 的 `templates/`、`scripts/`（目录说明见 [reference.md](reference.md)）。

### Step B：写 patch（只改必要点）

#### 1) `package.json` 常见 patch（几乎必做）

- `name` → `@ohos-npm-ports/<pkg>`
- `version` → `<upstream>-<rev>`
- `repository.url`、`bugs.url`（可选但建议）→ 维护仓库
- 如发布需要带 prebuild：确保 `files` 包含 `prebuilds/`

#### 2) 安装/加载框架选择（两种模式，默认选 B）

**A. 维持上游“预构建下载器”模式（如 prebuild-install）**  
仅当它支持自定义平台目录且你确认 OpenHarmony 能工作时才考虑；否则容易因为平台识别不匹配失败。

**B. 切换为本地选择预构建（推荐，sqlite3 模式）**

- JS 侧加载：`bindings` → `node-gyp-build`
  - `module.exports = require('node-gyp-build')(__dirname + "/../")`
- 预构建工具：`prebuild` → `prebuildify --napi`
- `scripts.install`：`node-gyp-build`
- 如上游存在 `binary.napi_versions` 且会影响流程，可移除并在构建侧固定（见下一条）

#### 3) N-API 版本策略（避免矩阵复杂化）

若上游支持多个 NAPI 版本但你只打算产出一个（示例固定为 6）：
- `binding.gyp` 中 `NAPI_VERSION=<(napi_build_version)` → 固定 `NAPI_VERSION=6`
- 构建/下载其他平台产物时确保命名与该版本一致（sqlite3 示例从 release 拉 `napi-v6`）

### Step C：写 `build.sh`（配方脚本）

遵循这一结构（bufferutil/sqlite3 的共同形态）：

1. `set -e`
2. `source ../../../setup-tools.sh` + `source ../../../build-env.sh`
3. 下载上游源码 tarball → 解压 → `patch -p1 < ../patchs/xxxx.patch`
4. `npm install` → `npm run prebuild`
5. 对 `prebuilds/openharmony-arm64/*.node` 签名
6. 获取其他平台 prebuild 并拷贝进 `prebuilds/`（从 npm tgz 或 GitHub release）
7. 按约定重命名 `.node` 为 `@ohos-npm-ports+<pkg>.node`（以及 glibc/musl 等变体）

你生成脚本时要把以下“可变项”抽成变量，便于复用：
- `PKG_NAME`（不带 scope）
- `UPSTREAM_VERSION`
- `PORT_REV`
- `UPSTREAM_TARBALL_URL`（源码）
- `UPSTREAM_PREBUILDS_SOURCE`（npm tgz 或 release base_url + asset_name 模板）
- `OH_NODE_PATH`（openharmony-arm64 的产物路径）

### Step D：写 `publish.sh`

进入源码目录后执行：
- `npm publish --tag latest --access public`

（如果你的流程用的是 dist-tag 或私有源，按项目要求替换，但结构保持一致。）

## 产物合并与命名规则（关键）

### 从 npm tgz 合并（bufferutil 模式）

- 下载 `https://registry.npmjs.org/<pkg>/-/<pkg>-<ver>.tgz`
- 解压得到 `package/`
- `cp -r package/prebuilds/* <your-src>/prebuilds/`
- 对各平台目录下的 `.node` 统一重命名为 `@ohos-npm-ports+<pkg>.node`

### 从 GitHub Releases 合并（sqlite3 模式）

- 通过 `base_url + asset_name` 批量下载并解压
- 从解压目录拷贝 `build/Release/*.node` 到 `./prebuilds/<platform>/@ohos-npm-ports+<pkg>.node`
- 若存在 `linux` 的 glibc/musl 差异：重命名为 `*.glibc.node` / `*.musl.node`，并清理中间目录

## 质量闸门（必须逐条过）

- [ ] `package.json` 中 `name/version` 已按约定修改
- [ ] `files` 覆盖 `prebuilds/`（否则 npm 包可能不包含产物）
- [ ] OpenHarmony 产物路径正确：`prebuilds/openharmony-arm64/@ohos-npm-ports+<pkg>.node`
- [ ] 已对 OpenHarmony `.node` 执行签名
- [ ] 运行时加载方式与产物布局一致（`node-gyp-build` 推荐）
- [ ] 合并进来的其他平台产物已重命名，且目录结构与 loader 匹配
- [ ] 清理临时下载/解压目录，保证配方可重复执行

## 输出要求（你给用户的交付物）

当用户让你“做鸿蒙化适配/写 port/写脚本/写 patch”时，最终至少交付：
- `ports/<pkg>/<version>/build.sh`
- `ports/<pkg>/<version>/publish.sh`
- `ports/<pkg>/<version>/patchs/*.patch`（最少一个）
- 一段简短说明：选择了哪种模式（bufferutil 类 / sqlite3 类）、NAPI 版本策略、prebuild 来源与合并方式

## 参考

已验证的 port 示例（用于对齐风格与产物布局）：
- `bufferutil 4.0.9`：见 `https://github.com/ohos-npm-ports/ohos-npm-ports/tree/main/ports/bufferutil/4.0.9`
- `sqlite3 5.1.7`：见 `https://github.com/ohos-npm-ports/ohos-npm-ports/tree/main/ports/sqlite3/5.1.7`
