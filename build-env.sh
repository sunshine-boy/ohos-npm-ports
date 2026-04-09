#!/bin/sh
# 鸿蒙容器内 JS 三方库编译前环境检测与补装（不调用仓库内其他脚本）
# 可被 `.` / `source` 作为前置脚本引入：成功/失败时用 `return N 2>/dev/null || exit N`，结束本段逻辑而不结束调用方 shell。
# pkg / ver 与制品包名 $pkg-$ver-ohos-arm64.tar.gz 一致

set -e

ATOMGIT_RELEASE="https://atomgit.com/CodexBai/ohos-temporary-software/releases/download/1.0.0"
INIT_ENV_CFG_NAME="js_pkg_oh_env_arm.cfg"
INIT_ENV_CFG_DEST_DIR="/system/etc/init"

NODE_ROOT="/opt/node-v24.2.0-openharmony-arm64"
NODE_TARBALL_URL="https://github.com/hqzing/ohos-node/releases/download/v24.2.0/node-v24.2.0-openharmony-arm64.tar.gz"
OHOS_SDK_LLVM_CLANG="/opt/ohos-sdk/ohos/native/llvm/bin/clang"
OHOS_SDK_OHOS_DIR="/opt/ohos-sdk/ohos"
OHOS_SDK_ZIP_NATIVE="native-ohos-x64-6.1.0.27-Canary1.zip"
OHOS_SDK_ZIP_TC="toolchains-ohos-x64-6.1.0.27-Canary1.zip"
OHOS_SDK_TAR_URL="https://cidownload.openharmony.cn/version/Master_Version/ohos-sdk-public_ohos/20260108_020526/version-Master_Version-ohos-sdk-public_ohos-20260108_020526-ohos-sdk-public_ohos.tar.gz"

# 将仓库内 init 环境配置拷贝到系统 init 目录（解压制品后由 install_from_atomgit 调用）
# 注意：被 source 时 $0 是调用方（如 ports/.../build.sh），不能仅用 dirname "$0"；需向上找到含 cfg 的仓库根
copy_js_pkg_env_cfg_to_system_init() {
    start=$(CDPATH= cd "$(dirname "$0")" && pwd) || return 1
    here=$start
    src=""
    while [ -n "$here" ]; do
        if [ -f "$here/$INIT_ENV_CFG_NAME" ]; then
            src="$here/$INIT_ENV_CFG_NAME"
            break
        fi
        parent=$(dirname "$here")
        [ "$parent" = "$here" ] && break
        here=$parent
    done
    if [ -z "$src" ] || [ ! -f "$src" ]; then
        printf '%s\n' "[build-env] ERROR: 未找到 $INIT_ENV_CFG_NAME（已从 $start 向父目录向上查找）" >&2
        return 1
    fi
    mkdir -p "$INIT_ENV_CFG_DEST_DIR"
    cp "$src" "$INIT_ENV_CFG_DEST_DIR/"
    printf '%s\n' "[build-env] 已复制 $INIT_ENV_CFG_NAME -> $INIT_ENV_CFG_DEST_DIR/"
}

# 尽力读取单行版本信息（--version / -version / -V，合并 stderr）
get_ver_line() {
    cmd=$1
    line=""
    line=$("$cmd" --version 2>&1 | head -n 1) || :
    if [ -z "$line" ]; then
        line=$("$cmd" -version 2>&1 | head -n 1) || :
    fi
    if [ -z "$line" ]; then
        line=$("$cmd" -V 2>&1 | head -n 1) || :
    fi
    printf '%s' "$line"
}

log_ok() {
    cmd=$1
    path=$(command -v "$cmd")
    ver=$(get_ver_line "$cmd")
    if [ -n "$ver" ]; then
        printf '%s\n' "[build-env] OK: $cmd -> $path 版本: $ver"
    else
        printf '%s\n' "[build-env] OK: $cmd -> $path（未能解析版本号）"
    fi
}

log_ok_as() {
    logical=$1
    real=$2
    path=$(command -v "$real")
    ver=$(get_ver_line "$real")
    if [ -n "$ver" ]; then
        printf '%s\n' "[build-env] OK: $logical（$real） -> $path 版本: $ver"
    else
        printf '%s\n' "[build-env] OK: $logical（$real） -> $path（未能解析版本号）"
    fi
}

log_miss() {
    printf '%s\n' "[build-env] 缺失: $1（PATH 与 /opt 均未解析到可用命令）" >&2
}

# $4=1 时在注入 /opt 的 bin 前打印提示；$4=0 用于补装后静默复检
# 返回 0 表示命令已可用（含 vim→nvim、python→python3）
tool_try_resolve() {
    cmd=$1
    pkg=$2
    ver=$3
    show_hints=$4

    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    inst_dir="/opt/$pkg-$ver-ohos-arm64"
    bindir="$inst_dir/bin"
    if [ -d "$bindir" ]; then
        if [ "$show_hints" = 1 ]; then
            printf '%s\n' "[build-env] PATH 中未找到 $cmd，检测到 $bindir，已加入 PATH 并重试"
        fi
        export PATH="$bindir:$PATH"
        if command -v "$cmd" >/dev/null 2>&1; then
            return 0
        fi
        case $cmd in
            vim)
                if command -v nvim >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            python)
                if command -v python3 >/dev/null 2>&1; then
                    return 0
                fi
                ;;
        esac
    elif [ -d "$inst_dir" ] && [ "$show_hints" = 1 ]; then
        printf '%s\n' "[build-env] 警告: $inst_dir 存在但缺少 bin 子目录，跳过 PATH 注入" >&2
    fi

    return 1
}

report_tool_ok() {
    cmd=$1
    case $cmd in
        vim)
            if command -v vim >/dev/null 2>&1; then
                log_ok vim
            elif command -v nvim >/dev/null 2>&1; then
                log_ok_as vim nvim
            fi
            ;;
        python)
            if command -v python >/dev/null 2>&1; then
                log_ok python
            elif command -v python3 >/dev/null 2>&1; then
                log_ok_as python python3
            fi
            ;;
        *)
            log_ok "$cmd"
            ;;
    esac
}

TOOLS_LIST="busybox	busybox	1.37.0
make	make	4.4.1
cmake	cmake	4.1.2
vim	vim	9.2.0150
git	git	2.53.0
python	python	3.14.3"

# $1 输出仍缺失的「cmd<TAB>pkg<TAB>ver」
# $2 若为非空文件路径：仅对该文件中列出的命令名在成功解析后执行 report_tool_ok（补装后复检）；show_hints=0
# $2 为空：首次检测，show_hints=1，凡成功则 report_tool_ok
collect_missing() {
    outfile=$1
    needed_cmds=$2
    : > "$outfile"
    if [ -n "$needed_cmds" ] && [ -f "$needed_cmds" ]; then
        hints=0
    else
        hints=1
    fi
    while IFS="$(printf '\t')" read -r cmd pkg ver; do
        [ -n "$cmd" ] && [ -n "$pkg" ] && [ -n "$ver" ] || continue
        if tool_try_resolve "$cmd" "$pkg" "$ver" "$hints"; then
            if [ -n "$needed_cmds" ] && [ -f "$needed_cmds" ]; then
                if grep -qFx "$cmd" "$needed_cmds"; then
                    report_tool_ok "$cmd"
                fi
            else
                report_tool_ok "$cmd"
            fi
        else
            log_miss "$cmd"
            printf '%s\t%s\t%s\n' "$cmd" "$pkg" "$ver" >> "$outfile"
        fi
    done <<EOF
$TOOLS_LIST
EOF
}

install_from_atomgit() {
    list=$1
    printf '%s\n' "[build-env] 从 atomgit 批量下载并解压至 /opt ..."
    while IFS="$(printf '\t')" read -r cmd pkg ver; do
        [ -n "$pkg" ] && [ -n "$ver" ] || continue
        file=$pkg-$ver-ohos-arm64.tar.gz
        url="$ATOMGIT_RELEASE/$file"
        printf '%s\n' "[build-env] 下载: $file"
        printf '%s\n' "[build-env] 地址: $url"
        (
            cd /tmp || exit 1
            if ! curl -fSLO --connect-timeout 60 --retry 3 --retry-delay 2 "$url"; then
                printf '%s\n' "[build-env] ERROR: 下载失败 $file" >&2
                exit 1
            fi
            tar -zxf "$file" -C /opt
            rm -f "$file"
        )
        printf '%s\n' "[build-env] 已解压到 /opt，配置 PATH: /opt/$pkg-$ver-ohos-arm64/bin"
        export PATH="/opt/$pkg-$ver-ohos-arm64/bin:$PATH"
    done < "$list"
    copy_js_pkg_env_cfg_to_system_init
}

# 解压 SDK 内 zip（busybox 或系统 unzip）
ohos_sdk_unzip_one() {
    zf=$1
    if command -v busybox >/dev/null 2>&1; then
        busybox unzip -q -o "$zf"
    elif command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$zf"
    else
        printf '%s\n' "[build-env] ERROR: 需要 busybox 或 unzip 以解压 ohos-sdk zip" >&2
        return 1
    fi
}

# 官方 tar 常带一层版本目录，zip 实际在 .../<某目录>/ohos/ 下
ohos_sdk_resolve_ohos_dir() {
    base=$1
    if [ -f "$base/$OHOS_SDK_ZIP_NATIVE" ] || [ -f "$base/$OHOS_SDK_ZIP_TC" ]; then
        printf '%s\n' "$base"
        return 0
    fi
    zpath=$(find /opt/ohos-sdk -type f \( -name "$OHOS_SDK_ZIP_NATIVE" -o -name "$OHOS_SDK_ZIP_TC" \) 2>/dev/null | head -n 1)
    if [ -n "$zpath" ]; then
        dirname "$zpath"
        return 0
    fi
    printf '%s\n' "$base"
}

# Node.js、/bin 软链、ohos-sdk 与 llvm 封装（已存在则跳过下载，仍完成 /bin 与封装配置）
install_node_ohos_sdk_and_bins() {
    printf '%s\n' "[build-env] 检查并完成 Node、ohos-sdk 与 /bin 工具链配置..."

    if [ -x "$NODE_ROOT/bin/node" ]; then
        printf '%s\n' "[build-env] Node 已存在于 $NODE_ROOT，跳过下载"
    else
        printf '%s\n' "[build-env] 下载并安装 Node.js..."
        (
            cd /tmp || exit 1
            curl -fSLO "$NODE_TARBALL_URL"
            tar -zxf node-v24.2.0-openharmony-arm64.tar.gz -C /opt
            rm -f node-v24.2.0-openharmony-arm64.tar.gz
        )
    fi

    printf '%s\n' "[build-env] 将 /opt 下 *-ohos-arm64/bin 链接到 /bin"
    find /opt -maxdepth 2 -type d | grep "arm64/bin$" | while IFS= read -r dir; do
        cd "$dir"
        ls | /opt/busybox-1.37.0-ohos-arm64/bin/busybox xargs -I {} sh -c "ln -s -f $(realpath {}) /bin/{}"
        cd - >/dev/null
    done

    oh_sdk_ohos=$OHOS_SDK_OHOS_DIR
    oh_sdk_clang="$OHOS_SDK_LLVM_CLANG"

    # 默认路径不对时（版本子目录、或仅残留已解压的 LLVM），在 /opt/ohos-sdk 下定位 clang
    if [ ! -f "$oh_sdk_clang" ]; then
        cfound=$(find /opt/ohos-sdk -type f -name clang 2>/dev/null | grep '/native/llvm/bin/clang$' | head -n 1)
        if [ -n "$cfound" ]; then
            oh_sdk_clang=$cfound
            oh_sdk_ohos=$(dirname "$(dirname "$(dirname "$cfound")")")
        fi
    fi

    if [ -f "$oh_sdk_clang" ]; then
        printf '%s\n' "[build-env] ohos-sdk（LLVM）已就绪，跳过 SDK 归档下载与 zip 解压"
    else
        oh_sdk_ohos=$(ohos_sdk_resolve_ohos_dir "$OHOS_SDK_OHOS_DIR")
        oh_sdk_clang="$oh_sdk_ohos/native/llvm/bin/clang"
        if [ -f "$oh_sdk_ohos/$OHOS_SDK_ZIP_NATIVE" ] || [ -f "$oh_sdk_ohos/$OHOS_SDK_ZIP_TC" ]; then
            printf '%s\n' "[build-env] 检测到 SDK zip（目录: $oh_sdk_ohos），仅解压 native/toolchains（不下载归档）"
            (
                cd "$oh_sdk_ohos" || exit 1
                [ -f "$OHOS_SDK_ZIP_NATIVE" ] && ohos_sdk_unzip_one "$OHOS_SDK_ZIP_NATIVE" # 官方命名 x64，实为 arm64
                [ -f "$OHOS_SDK_ZIP_TC" ] && ohos_sdk_unzip_one "$OHOS_SDK_ZIP_TC"
                rm -rf ./*.zip 2>/dev/null || true
            )
        else
            printf '%s\n' "[build-env] 下载并解压 ohos-sdk 归档..."
            (
                cd /tmp || exit 1
                curl -fSL -o ohos-sdk.tar.gz "$OHOS_SDK_TAR_URL"
                mkdir -p /opt/ohos-sdk
                tar -zxf ohos-sdk.tar.gz -C /opt/ohos-sdk
                rm -f ohos-sdk.tar.gz
            )
            oh_sdk_ohos=$(ohos_sdk_resolve_ohos_dir "$OHOS_SDK_OHOS_DIR")
            oh_sdk_clang="$oh_sdk_ohos/native/llvm/bin/clang"
            if [ ! -f "$oh_sdk_ohos/$OHOS_SDK_ZIP_NATIVE" ] && [ ! -f "$oh_sdk_ohos/$OHOS_SDK_ZIP_TC" ]; then
                printf '%s\n' "[build-env] ERROR: 解压归档后未找到 SDK zip（期望含 $OHOS_SDK_ZIP_NATIVE）" >&2
                find /opt/ohos-sdk -maxdepth 4 -type f -name "*.zip" 2>/dev/null | head -20 >&2 || true
                return 1
            fi
            (
                cd "$oh_sdk_ohos" || exit 1
                [ -f "$OHOS_SDK_ZIP_NATIVE" ] && ohos_sdk_unzip_one "$OHOS_SDK_ZIP_NATIVE"
                [ -f "$OHOS_SDK_ZIP_TC" ] && ohos_sdk_unzip_one "$OHOS_SDK_ZIP_TC"
                rm -rf ./*.zip 2>/dev/null || true
            )
        fi
    fi

    # 与 setup-tools.sh 一致：官方 LLVM 常无执行位，须先 chmod 再检测 -x
    if [ -d "$oh_sdk_ohos/native/llvm/bin" ]; then
        chmod 0755 "$oh_sdk_ohos/native/llvm/bin/"* 2>/dev/null || true
    fi
    if [ -f "$oh_sdk_ohos/toolchains/lib/binary-sign-tool" ]; then
        chmod 0755 "$oh_sdk_ohos/toolchains/lib/binary-sign-tool"
    fi

    if [ ! -x "$oh_sdk_clang" ]; then
        printf '%s\n' "[build-env] ERROR: ohos-sdk LLVM 仍未就绪: $oh_sdk_clang（oh_sdk_ohos=$oh_sdk_ohos）" >&2
        ls -la "$oh_sdk_ohos" 2>/dev/null | head -30 >&2 || true
        return 1
    fi

    essential_tools="clang
clang++
ld.lld
lldb
llvm-addr2line
llvm-ar
llvm-cxxfilt
llvm-nm
llvm-objcopy
llvm-objdump
llvm-ranlib
llvm-readelf
llvm-size
llvm-strip"

    for executable in $essential_tools; do
        cat <<EOF >"/bin/$executable"
#!/bin/sh
exec "$oh_sdk_ohos/native/llvm/bin/$executable" "\$@"
EOF
        chmod 0755 "/bin/$executable"
    done

    ln -sf "$oh_sdk_ohos/toolchains/lib/binary-sign-tool" /bin/binary-sign-tool

    cd /bin
    ln -sf clang cc
    ln -sf clang gcc
    ln -sf clang++ c++
    ln -sf clang++ g++
    ln -sf ld.lld ld
    ln -sf llvm-addr2line addr2line
    ln -sf llvm-ar ar
    ln -sf llvm-cxxfilt c++filt
    ln -sf llvm-nm nm
    ln -sf llvm-objcopy objcopy
    ln -sf llvm-objdump objdump
    ln -sf llvm-ranlib ranlib
    ln -sf llvm-readelf readelf
    ln -sf llvm-size size
    ln -sf llvm-strip strip
    cd - >/dev/null
}

missingf="/tmp/build-env-missing-$$"
neededf="/tmp/build-env-needed-$$"
trap 'rm -f "$missingf" "$neededf"' EXIT INT HUP

collect_missing "$missingf" ""

if [ ! -s "$missingf" ]; then
    printf '%s\n' "[build-env] 环境检测通过，所需命令均已可用。"
    install_node_ohos_sdk_and_bins
    return 0 2>/dev/null || exit 0
fi

cut -f1 "$missingf" > "$neededf"

printf '%s\n' "[build-env] 以下工具仍缺失，将尝试自动安装:"
while IFS="$(printf '\t')" read -r c p v; do
    [ -n "$c" ] || continue
    printf '%s\n' "[build-env]   - $c (制品: $p-$v-ohos-arm64)"
done < "$missingf"

if command -v brew >/dev/null 2>&1; then
    printf '%s\n' "[build-env] 已检测到 brew，执行 brew install ..."
    to_install=$(cut -f1 "$missingf" | tr '\n' ' ')
    # shellcheck disable=SC2086
    brew install $to_install
else
    printf '%s\n' "[build-env] 未检测到 brew，改为从 atomgit 拉取制品包。"
    if ! command -v curl >/dev/null 2>&1; then
        printf '%s\n' "[build-env] ERROR: 需要 curl 以下载制品，且当前无 brew。" >&2
        return 1 2>/dev/null || exit 1
    fi
    install_from_atomgit "$missingf"
fi

collect_missing "$missingf" "$neededf"

if [ -s "$missingf" ]; then
    printf '%s\n' "[build-env] 自动安装后仍缺失:" >&2
    cut -f1 "$missingf" >&2
    return 1 2>/dev/null || exit 1
fi

printf '%s\n' "[build-env] 补装后复检通过，所需命令均已可用。"
install_node_ohos_sdk_and_bins
return 0 2>/dev/null || exit 0
