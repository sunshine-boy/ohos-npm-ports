# patchs/

本目录放置对上游源码的 `patch -p1` 补丁（在解压后的 `package/` 根目录应用）。

## 必备：`0001-*.patch`

### 轻量模式（light）

至少修改 `package.json`：

- `name` → `@tetcl/electron-active-window`
- `version` → `0.0.6-2`（与发布版本一致；port rev 递增时同步修改）
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
- `binding.gyp`：`eaw_oh_port` 在 **`ELECTRON_ACTIVE_WINDOW_OH_PORT=1`** 或 **`process.execPath` 含 `openharmony`**（典型为 OpenHarmony Node 安装路径）时为 1，与 `OS=="openharmony"` 时走 OpenHarmony 存根；`OS=="linux"` 且 `eaw_oh_port!=1` 时仍编 X11。`build.sh` 仍会导出 `ELECTRON_ACTIVE_WINDOW_OH_PORT=1` 作为显式开关。Linux 桌面路径下 `-l*` 仅通过 `libraries` 链接，不再写入 `cflags`，避免 `-Wunused-command-line-argument`。`NODE_API_MODULE(wm, …)`（故 `build.sh` 将 `wm.node` 重命名为 `@tetcl+electron-active-window.node`）
- `files`：包含 `prebuilds/`

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-*.patch
```
