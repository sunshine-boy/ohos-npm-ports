# patchs/

对解压后的 `napi-rs-cli-<ver>/` 根目录执行 `patch -p1`。

## `0001-update-package-json.patch`

- `name` → `@tetcl/napi-rs-cli`（与仓库内其它 port 的 `@tetcl` scope 一致）
- `version` → `3.6.0-2`（`<上游>-<port rev>`；改 port 时递增）
- `repository.url` → `git+https://github.com/sunshine-boy/ohos-npm-ports.git`
- `bugs.url` → `https://github.com/sunshine-boy/ohos-npm-ports/issues`

上游 CLI 仍提供 `bin`：`napi` / `napi-raw`；安装后使用 `npx @tetcl/napi-rs-cli`（或包内声明的 bin 名，以 `package.json` 为准）。

## 校验

```bash
cd napi-rs-cli-3.6.0
patch -p1 --dry-run < ../patchs/0001-update-package-json.patch
```
