# patchs/

对解压后的 `napi-rs-cli-<ver>/` 根目录执行 `patch -p1`。

## `0001-update-package-json.patch`

- `name` → `@tetcl/napi-rs-cli`（与仓库内其它 port 的 `@tetcl` scope 一致）
- `version` → `3.6.0-3`（`<上游>-<port rev>`；改 port 时递增）
- `repository.url` → `git+https://github.com/sunshine-boy/ohos-npm-ports.git`
- `bugs.url` → `https://github.com/sunshine-boy/ohos-npm-ports/issues`

上游 CLI 仍提供 `bin`：`napi` / `napi-raw`；安装后使用 `npx @tetcl/napi-rs-cli`（或包内声明的 bin 名，以 `package.json` 为准）。

## `0002-template-archive-fallback.patch`

`napi new` 默认用 `git clone` / `git fetch` 拉取 [package-template](https://github.com/napi-rs/package-template)。在 OpenHarmony 等设备上常因证书、网络或损坏缓存出现 **git 退出码 128**。本补丁：

- 修正 `checkGitCommand()`（原先几乎总判定为「有 git」）。
- **git 失败时**自动改用 HTTPS 下载 `main` 分支的 **`.tar.gz`**，并用系统 **`tar -xzf`** 解压到模板缓存（需 `tar` 在 `PATH`）。
- 环境变量（可选）：
  - **`NAPI_RS_TEMPLATE_USE_ARCHIVE=1`**：跳过 git，只用归档（无 git 也可用）。
  - **`NAPI_RS_PACKAGE_TEMPLATE_ARCHIVE_URL`** / **`NAPI_RS_PACKAGE_TEMPLATE_PNPM_ARCHIVE_URL`**：覆盖 yarn / pnpm 模板归档 URL（便于镜像站）。

## 校验

```bash
cd napi-rs-cli-3.6.0
patch -p1 --dry-run < ../patchs/0001-update-package-json.patch
patch -p1 --dry-run < ../patchs/0002-template-archive-fallback.patch
```
