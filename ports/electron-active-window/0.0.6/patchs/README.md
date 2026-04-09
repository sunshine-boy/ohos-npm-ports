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
- `binding.gyp`：`OS=="openharmony"` 与 OpenHarmony 存根实现；`NODE_API_MODULE(wm, …)`（故 `build.sh` 将 `wm.node` 重命名为 `@tetcl+electron-active-window.node`）
- `files`：包含 `prebuilds/`

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-*.patch
```
