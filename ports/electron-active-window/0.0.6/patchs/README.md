# patchs/

本目录放置对上游源码的 `patch -p1` 补丁（在解压后的 `package/` 根目录应用）。

## 必备：`0001-*.patch`

### 轻量模式（light）

至少修改 `package.json`：

- `name` → `@tetcl/electron-active-window`
- `version` → `0.0.6-3`（与发布版本一致；port rev 递增时同步修改）
- `repository` / `bugs` → 维护仓库（与 js-native 一致：`git+https://github.com/sunshine-boy/ohos-npm-ports.git`）

生成方式示例：

```bash
tar -zxf package.tar.gz
cd package
git init && git add -A && git commit -m "upstream 0.0.6"
# 手工编辑 package.json 后：
git diff > ../patchs/0001-update-package-json.patch
```

### 框架模式（framework）

本 port 使用 **0001-change-prebuild-framework.patch**，除 `package.json` 外包含：

- 加载：`index.js` → `node-gyp-build`
- 脚本：`prebuild` → `prebuildify --napi`，`install` → `node-gyp-build`
- `binding.gyp`：`eaw_oh_port` 由 **`scripts/gyp-is-openharmony-port.js`** 判定（在 gyp 阶段执行）：显式 **`ELECTRON_ACTIVE_WINDOW_OH_PORT=1`**、`process.platform === 'openharmony'`、`execPath` 含 `openharmony`、**`CC`/`CXX` 等含 `linux-ohos` / `aarch64-linux-ohos` 等 OH 工具链**、**`/etc/os-release`（及 `/usr/etc/os-release`）** 中 `ID=openharmony` / `ID=ohos` 或 `NAME=` 含 OpenHarmony、**`/proc/version` 含 openharmony/ohos** 时输出 1，走 **`cppsrc/openharmony/windowopenharmony.cpp`**（无 X11）；`OS=="linux"` 且 `eaw_oh_port!=1` 时仍编 **X11**（Windows/mac 分支不变）。`build.sh` 仍会导出 `ELECTRON_ACTIVE_WINDOW_OH_PORT=1` 作为 CI 显式开关。Linux 桌面路径下 `-l*` 仅通过 `libraries` 链接。`NODE_API_MODULE(wm, …)`（故 `build.sh` 将 `wm.node` 重命名为 `@tetcl+electron-active-window.node`）
- `cppsrc/openharmony/windowopenharmony.cpp`：OpenHarmony 上返回与 Linux 成功路径一致的字段（无 `error`），`windowName`/`windowClass` 尽力填入 **`/proc/self/cmdline` 的 argv0**（当前 Node 进程名，便于标识运行环境；系统级「前台应用」需后续接系统 WM/Ability API）
- `files`：包含 `prebuilds/`

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-*.patch
```
