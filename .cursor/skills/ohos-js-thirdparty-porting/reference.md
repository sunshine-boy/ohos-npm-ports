## 脚手架与模板路径

本 skill 目录结构：

```text
ohos-js-thirdparty-porting/
├── SKILL.md
├── reference.md
├── examples.md
├── scripts/
│   └── new-port.sh          # 生成 ports/<pkg>/<ver>/ 配方
└── templates/
    ├── build-light.sh.tpl
    ├── build-framework.sh.tpl
    ├── publish.sh.tpl
    └── patchs-README.md.tpl
```

- **`new-port.sh`**：在目标仓库根目录执行（或用 `--output-root`），生成 `build.sh` / `publish.sh` / `patchs/README.md`。`bash scripts/new-port.sh --help` 查看全部参数。
- **模板**：由脚本做占位符替换；若需大改，可直接编辑生成后的 `build.sh`，或 fork 模板文件。

将本 skill 复制到 **ohos-npm-ports** 仓库的 `.cursor/skills/` 后，可把示例中的 `/path/to/ohos-js-thirdparty-porting/scripts/new-port.sh` 换成仓库内相对路径。

## 适配时的“最小改动优先”原则

- **先让包能在 OH 上安装 + require 成功**，再考虑性能/兼容性优化。
- patch 尽量只改：
  - 包名/版本/发布内容（`files`）
  - 运行时加载（`bindings` → `node-gyp-build`）
  - 预构建框架（`prebuild` → `prebuildify`）
  - NAPI 版本策略（固定为单一版本以降低矩阵）

## 产物布局与 loader 对齐

推荐组合：
- `node-gyp-build` + `prebuildify --napi`

理由：
- `node-gyp-build` 直接按目录扫描合适的 `.node`，更适合“把各平台 prebuild 都放在包里一起发”的模式。

## 版本后缀（port-rev）建议

- 初次 port：`-1`
- 每次仅修补配方/patch/脚本但不变上游版本：`-2/-3/...`
- 不要覆盖既有版本（npm 上一旦发布即不可变更，避免破坏依赖方缓存）

## 多平台预构建来源选择

### A. 从 npm tgz 取（优先）

适用：上游包本身已经把 prebuild 放在 npm 包里。

流程：
- 下载 npm tgz → 解压 → 复制 `package/prebuilds/*`

### B. 从 GitHub Releases 取

适用：上游把二进制作为 release asset 发布，npm 包未必含全部 prebuild。

流程：
- 组合 `base_url` + `asset_name` 批量下载
- 解压后从固定路径（常见 `build/Release/*.node`）取出二进制

## 常见坑位清单

- **npm 包没带 prebuild**：`files` 漏了 `prebuilds/`
- **OH 产物未签名**：导致安装或运行期校验失败
- **产物命名不一致**：脚本重命名了，但 loader 仍按老名字找（或反之）
- **NAPI 版本不一致**：OH 编出来是 vX，但你从上游合并的是 vY
- **linux musl/glibc 混淆**：建议明确重命名并保留两个变体（如示例）

