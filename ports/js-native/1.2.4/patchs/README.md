# patchs/

本目录放置对上游源码的 `patch -p1` 补丁（在解压后的 `package/` 根目录应用）。

## 必备：`0001-*.patch`

### 轻量模式（light）

至少修改 `package.json`：

- `name` → `@tetclbxm/js-native`
- `version` → `1.2.4-1`（与发布版本一致）
- `repository` / `bugs`（建议）→ 维护仓库（本 port 保持现有链接，未随组织名修改）

生成方式示例：

```bash
tar -zxf package.tar.gz
cd package
git init && git add -A && git commit -m "upstream 1.2.4"
# 手工编辑 package.json 后：
git diff > ../patchs/0001-update-package-json.patch
```

### 框架模式（framework）

除 `package.json` 外，通常还需：

- 加载：`bindings` → `node-gyp-build`
- 脚本：`prebuild` → `prebuildify --napi`，`install` → `node-gyp-build`
- `binding.gyp`：按需固定 `NAPI_VERSION`
- `files`：包含 `prebuilds/`

文件名建议：`0001-change-prebuild-framework.patch`（与 `build.sh` 中 `patch` 行一致即可）。

## 校验

```bash
cd package
patch -p1 --dry-run < ../patchs/0001-*.patch
```
