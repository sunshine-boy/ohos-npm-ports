# patchs/

对上游 `@mapbox/node-pre-gyp@2.0.3` 解压后的 `package/` 根目录执行 `patch -p1`。

## `0001-openharmony-platform.patch`

- **`lib/util/versioning.js`**：增加 `resolve_host_platform()` 与增强版 **`host_seems_openharmony()`**。除 `process.platform === 'openharmony'` 与 **`/etc/os-release`**（及 `/usr/etc/os-release`）中的 `ID=openharmony` / `ID=ohos` 外，还对 **`os.release()`** 中含 **`harmonyos` / `openharmony` / `hongmeng`** 的 **鸿蒙 PC（内核名常为 HongMeng）** 视为 OpenHarmony 主机，便于 `…-openharmony-*.tar.gz` 与后续工具链逻辑一致。可通过 **`NODE_PRE_GYP_PLATFORM`** 强制覆盖。
- **`lib/testbinary.js`**：在目标平台为 `openharmony` 且主机为「Linux 上的 OpenHarmony」时仍执行 `testbinary`，避免误跳过。
- **`package.json`**：`name` → `@tetcl/node-pre-gyp`，`version` → `2.0.3-5`，`repository` / `bugs` 与 **`ports/js-native`** 一致（`git+https://github.com/sunshine-boy/ohos-npm-ports.git` / `https://github.com/sunshine-boy/ohos-npm-ports/issues`）。

业务侧若仍依赖包名 `@mapbox/node-pre-gyp`，可使用 npm **`overrides`** 或改为依赖 **`@tetcl/node-pre-gyp`**，并相应调整子依赖中的 `peerDependencies`（如有）。

## `0002-gyp-env-sanitize-ohos-llvm.patch`

- 对 **`lib/util/compile.js`** 使用**单个 hunk**（整文件替换式 unified diff），避免 BusyBox `patch` 在多 hunk 下不累计行号导致 **Hunk 2 FAILED**。
- **`lib/util/compile.js`**：在 `spawn` **node-gyp** 前构造专用环境变量副本。
  - 若 **`CC` / `CXX` / `LINK` / `AR` 等**（含 **`npm_config_cc` / `npm_config_cxx`**）的首个参数为**绝对路径**且该文件**不存在**（常见于 CI 注入的 `/home/runner/.../clang++`），则**删除**这些项，避免 `make` 引用无效编译器。
  - 若清理后仍缺少可用的 **`CC`/`CXX`**，且满足 **OpenHarmony 主机**（`openharmony` 平台或 **`host_seems_openharmony()`**），或 **`linux` 且** 已设置 **`OHOS_SDK_ROOT` / `OHOS_SDK_OHOS_DIR` / `OHOS_SDK_LLVM_CLANG` / `OHOS_SDK_NATIVE_LLVM_BIN`** 之一，则按顺序探测 LLVM **`bin`** 目录并设置 **`CC`/`CXX`**：**`OHOS_SDK_NATIVE_LLVM_BIN`**、**`OHOS_SDK_ROOT`** 下的 **`linux/native/llvm/bin`** 或 **`ohos-sdk/linux/native/llvm/bin`**、**`OHOS_SDK_LLVM_CLANG`** 的父目录、**`OHOS_SDK_OHOS_DIR/native/llvm/bin`**、**/opt/ohos-sdk/ohos/native/llvm/bin**。

日志里若仍出现 **`/home/runner/.../clang++`**，说明 **`node-pre-gyp` 仍为旧版**（例如 `2.0.3-1` 无 `compile.js` 补丁）或 **`build/`** 里 Makefile 为旧次 configure 生成：请安装 **`@tetcl/node-pre-gyp@2.0.3-5`**（本 port 打齐 `0001`+`0002`），导出 **`OHOS_SDK_ROOT`**，并删除工程下 **`build/`** 后重新 **`npm install`**。

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-openharmony-platform.patch
patch -p1 --dry-run < ../patchs/0002-gyp-env-sanitize-ohos-llvm.patch
```
