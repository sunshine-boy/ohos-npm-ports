# patchs/

对解压后的 `node-sqlcipher-5.3.1/` 根目录执行 `patch -p1`。

## `0001-change-prebuild-framework.patch`

将上游 [@journeyapps/sqlcipher](https://www.npmjs.com/package/@journeyapps/sqlcipher) 使用的 `@mapbox/node-pre-gyp` 安装流改为与本仓库其他原生包一致的 **node-gyp-build + prebuildify**（参见 `ports/sqlite3`）：

- `binding.gyp`：在 `variables` 中补充 `module_name`（原为 `node-pre-gyp` 从 `package.json` 的 `binary` 注入）；固定 `NAPI_VERSION=6`；去掉依赖未定义的 `module_path` 的 `action_after_build` 拷贝目标（产物留在 `build/Release/`，由 `node-gyp-build` / `prebuildify` 消费）。
- `lib/sqlite3-binding.js`：改为 `require('node-gyp-build')`。
- `package.json`：发布名为 `@tetcl/sqlcipher`，版本 `5.3.1-1`；`repository` / `bugs` 指向本 ports 仓库；`files` 包含 `prebuilds/`、`deps/`、`src/`。

业务侧仍可 `require('@tetcl/sqlcipher')`，API 与 [journeyapps/node-sqlcipher](https://github.com/journeyapps/node-sqlcipher) 一致（加密库为 SQLCipher）。

## 校验

```bash
cd node-sqlcipher-5.3.1
patch -p1 --dry-run < ../patchs/0001-change-prebuild-framework.patch
```

若本机 `package.json` 为 CRLF（`git` 的 `autocrlf` 等），请先去掉回车再执行 patch，否则 `package.json` 相关 hunk 会全部失败。`build.sh` 已在打补丁前对 `package.json` 等文件做去 `\r` 处理。
