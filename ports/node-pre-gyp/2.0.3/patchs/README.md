# patchs/

对上游 `@mapbox/node-pre-gyp@2.0.3` 解压后的 `package/` 根目录执行 `patch -p1`。

## `0001-openharmony-platform.patch`

- **`lib/util/versioning.js`**：增加 `resolve_host_platform()`。在未显式指定 `--target_platform` 时：若 `process.platform === 'openharmony'`，或 **Linux 且** `/etc/os-release`（及 `/usr/etc/os-release`）中 `ID=openharmony` / `ID=ohos`，则将 `{platform}` / `target_platform` 规范为 **`openharmony`**，便于安装 `…-openharmony-arm64.tar.gz` 等预编译包。可通过环境变量 **`NODE_PRE_GYP_PLATFORM`** 强制覆盖（例如在未识别到的系统上仍要拉取 `linux` 包时设为 `linux`）。
- **`lib/testbinary.js`**：在目标平台为 `openharmony` 且主机为「Linux 上的 OpenHarmony」时仍执行 `testbinary`，避免误跳过。
- **`package.json`**：`name` → `@tetcl/node-pre-gyp`，`version` → `2.0.3-3`，`repository` / `bugs` 与 **`ports/js-native`** 一致（`git+https://github.com/sunshine-boy/ohos-npm-ports.git` / `https://github.com/sunshine-boy/ohos-npm-ports/issues`）。

业务侧若仍依赖包名 `@mapbox/node-pre-gyp`，可使用 npm **`overrides`** 或改为依赖 **`@tetcl/node-pre-gyp`**，并相应调整子依赖中的 `peerDependencies`（如有）。

## `0002-gyp-env-sanitize-ohos-llvm.patch`

- **`lib/util/compile.js`**：在 `spawn` **node-gyp** 前构造专用环境变量副本。
  - 若 **`CC` / `CXX` / `LINK` / `AR` 等**（含 **`npm_config_cc` / `npm_config_cxx`**）的首个参数为**绝对路径**且该文件**不存在**（常见于 CI 注入的 `/home/runner/.../clang++`），则**删除**这些项，避免 `make` 引用无效编译器。
  - 在 **OpenHarmony 主机**（`process.platform === 'openharmony'` 或 `versioning.host_seems_openharmony()`）上，若清理后仍缺少可用的 `CC`/`CXX`，则按顺序探测：**`OHOS_SDK_NATIVE_LLVM_BIN`**（含 `clang` 的目录）、**`OHOS_SDK_ROOT`** 下的 **`linux/native/llvm/bin`** 或 **`ohos-sdk/linux/native/llvm/bin`**（鸿蒙 PC / DevEco 常见）、**`OHOS_SDK_LLVM_CLANG`** 的父目录、**`OHOS_SDK_OHOS_DIR/native/llvm/bin`**、**/opt/ohos-sdk/ohos/native/llvm/bin**，存在则设置 **`CC`/`CXX`**。

若设备上 SDK 不在上述路径，请导出 **`OHOS_SDK_ROOT`**（推荐）或 **`OHOS_SDK_NATIVE_LLVM_BIN`** / **`OHOS_SDK_OHOS_DIR`** / **`OHOS_SDK_LLVM_CLANG`** 后再执行 `npm install`。仍异常时可删除模块目录下的 **`build/`** 后重试，避免沿用旧 Makefile。

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-openharmony-platform.patch
patch -p1 --dry-run < ../patchs/0002-gyp-env-sanitize-ohos-llvm.patch
```
