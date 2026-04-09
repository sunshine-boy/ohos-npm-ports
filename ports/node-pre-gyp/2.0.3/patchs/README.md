# patchs/

对上游 `@mapbox/node-pre-gyp@2.0.3` 解压后的 `package/` 根目录执行 `patch -p1`。

## `0001-openharmony-platform.patch`

- **`lib/util/versioning.js`**：增加 `resolve_host_platform()`。在未显式指定 `--target_platform` 时：若 `process.platform === 'openharmony'`，或 **Linux 且** `/etc/os-release`（及 `/usr/etc/os-release`）中 `ID=openharmony` / `ID=ohos`，则将 `{platform}` / `target_platform` 规范为 **`openharmony`**，便于安装 `…-openharmony-arm64.tar.gz` 等预编译包。可通过环境变量 **`NODE_PRE_GYP_PLATFORM`** 强制覆盖（例如在未识别到的系统上仍要拉取 `linux` 包时设为 `linux`）。
- **`lib/testbinary.js`**：在目标平台为 `openharmony` 且主机为「Linux 上的 OpenHarmony」时仍执行 `testbinary`，避免误跳过。
- **`package.json`**：`name` → `@tetcl/node-pre-gyp`，`version` → `2.0.3-1`，`repository` / `bugs` 与 **`ports/js-native`** 一致（`git+https://github.com/sunshine-boy/ohos-npm-ports.git` / `https://github.com/sunshine-boy/ohos-npm-ports/issues`）。

业务侧若仍依赖包名 `@mapbox/node-pre-gyp`，可使用 npm **`overrides`** 或改为依赖 **`@tetcl/node-pre-gyp`**，并相应调整子依赖中的 `peerDependencies`（如有）。

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-openharmony-platform.patch
```
