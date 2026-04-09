#!/bin/sh
# 鸿蒙容器内 JS 三方库编译前环境检测（不调用仓库内其他脚本）
# pkg / ver 与 setup-tools.sh 解压目录 /opt/$pkg-$ver-ohos-arm64 保持一致

set -e

log_ok() {
    printf '%s\n' "[build-env] OK: $1 -> $(command -v "$1")"
}

log_miss() {
    printf '%s\n' "[build-env] 缺失: $1（PATH 与 /opt 均未解析到可用命令）" >&2
}

missing=""
# 每行: 待检测命令名<TAB>opt 目录中的软件包名<TAB>版本号
while IFS="$(printf '\t')" read -r cmd pkg ver; do
    [ -n "$cmd" ] && [ -n "$pkg" ] && [ -n "$ver" ] || continue

    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "$cmd"
        continue
    fi

    inst_dir="/opt/$pkg-$ver-ohos-arm64"
    bindir="$inst_dir/bin"
    if [ -d "$bindir" ]; then
        printf '%s\n' "[build-env] PATH 中未找到 $cmd，检测到 $bindir，已加入 PATH 并重试"
        export PATH="$bindir:$PATH"
        if command -v "$cmd" >/dev/null 2>&1; then
            log_ok "$cmd"
            continue
        fi
        case $cmd in
            vim)
                if command -v nvim >/dev/null 2>&1; then
                    printf '%s\n' "[build-env] OK: vim（实际为 nvim） -> $(command -v nvim)"
                    continue
                fi
                ;;
            python)
                if command -v python3 >/dev/null 2>&1; then
                    printf '%s\n' "[build-env] OK: python（实际为 python3） -> $(command -v python3)"
                    continue
                fi
                ;;
        esac
    elif [ -d "$inst_dir" ]; then
        printf '%s\n' "[build-env] 警告: $inst_dir 存在但缺少 bin 子目录，跳过 PATH 注入" >&2
    fi

    log_miss "$cmd"
    missing="${missing}${missing:+ }$cmd"
done <<'EOF'
busybox	busybox	1.37.0
make	make	4.4.1
cmake	cmake	4.1.2
vim	vim	9.2.0150
git	git	2.45.2
python	python	3.14.3
EOF

if [ -n "$missing" ]; then
    printf '%s\n' "[build-env] 环境检测失败，缺少: $missing" >&2
    printf '%s\n' "[build-env] 请安装对应工具或解压到 /opt/\$pkg-\$ver-ohos-arm64 并包含 bin。" >&2
    exit 1
fi

printf '%s\n' "[build-env] 环境检测通过，所需命令均已可用。"
exit 0
