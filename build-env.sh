#!/bin/sh
# 鸿蒙容器中 JS 三方库编译前的环境检测（后续可在此扩展安装逻辑）
# 用法: sh build-env.sh  或  . ./build-env.sh（失败时 return/exit 行为见文末）

build_env_log() {
    printf '%s\n' "[build-env] $*"
}

build_env_err() {
    printf '%s\n' "[build-env] ERROR: $*" >&2
}

# 依次检测：展示名、候选可执行名（任一在 PATH 中即通过）
missing=

check_cmd() {
    label=$1
    shift
    found=
    for c in "$@"; do
        if command -v "$c" >/dev/null 2>&1; then
            build_env_log "OK: $label ($c) -> $(command -v "$c")"
            found=1
            break
        fi
    done
    if [ -z "$found" ]; then
        build_env_err "缺少命令: $label（期望 PATH 中至少存在其一: $*）"
        missing=1
    fi
}

build_env_log "开始检测编译依赖命令..."

check_cmd busybox busybox
check_cmd make make
check_cmd cmake cmake
# setup-tools 安装的是 neovim，通常提供 nvim；兼容系统自带的 vim
check_cmd "vim/nvim(编辑器)" vim nvim
check_cmd git git
check_cmd python python python3

if [ -n "$missing" ]; then
    build_env_err "环境不完整。请在仓库根目录以合适权限执行 setup-tools.sh 安装工具，并确保 PATH 包含 /bin 及各 /opt/*-ohos-arm64/bin。"
    return 1 2>/dev/null || exit 1
fi

build_env_log "所需命令检测通过。"
return 0 2>/dev/null || exit 0
