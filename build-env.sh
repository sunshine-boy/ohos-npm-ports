#!/bin/sh
# 鸿蒙容器内 JS 三方库编译前环境检测（不依赖仓库内其他安装脚本）

set -e

log_ok() {
    printf '%s\n' "[build-env] OK: $1 -> $(command -v "$1")"
}

log_miss() {
    printf '%s\n' "[build-env] 缺失: $1（PATH 中未找到可执行文件）" >&2
}

# 编译链路所需命令（与 setup-tools 等脚本无调用关系，仅做存在性检测）
REQUIRED_CMDS="busybox make cmake vim git python"
missing=""

for cmd in $REQUIRED_CMDS; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "$cmd"
    else
        log_miss "$cmd"
        missing="${missing}${missing:+ }$cmd"
    fi
done

if [ -n "$missing" ]; then
    printf '%s\n' "[build-env] 环境检测失败，缺少: $missing" >&2
    printf '%s\n' "[build-env] 请先在容器内安装上述工具并保证其在 PATH 中可用。" >&2
    exit 1
fi

printf '%s\n' "[build-env] 环境检测通过，所需命令均已可用。"
exit 0
