#!/bin/sh
set -e

# 需要下载的软件包清单
echo "busybox 1.37.0
make 4.4.1
cmake 4.1.2
neovim 0.11.4
git 2.45.2
python 3.14.3" >/tmp/tools.txt

# 批量下载解压软件包
tools_log() {
    printf '%s\n' "[setup-tools] $*"
}

tools_err() {
    printf '%s\n' "[setup-tools] ERROR: $*" >&2
}

while read -r name ver; do
    [ -n "$name" ] && [ -n "$ver" ] || continue
    file=$name-$ver-ohos-arm64.tar.gz
    url="https://github.com/Harmonybrew/ohos-$name/releases/download/$ver/$file"
    tools_log "准备下载软件包: $name (版本 $ver)"
    tools_log "目标文件: $file"
    tools_log "下载地址: $url"
    if ! curl -fSLO --connect-timeout 60 --retry 3 --retry-delay 2 "$url"; then
        tools_err "下载失败 — 软件包: $name $ver, 文件: $file"
        tools_err "请检查网络、代理或 Release 页面是否仍存在该制品。"
        exit 1
    fi
    tools_log "下载成功: $file，开始解压到 /opt"
    if ! tar -zxf "$file" -C /opt; then
        tools_err "解压失败 — 文件: $file（已保留在当前目录便于排查）"
        exit 1
    fi
    rm -f "$file"
    tools_log "已完成: $name $ver"
done </tmp/tools.txt

# 下载 Node.js
curl -fSLO https://github.com/hqzing/ohos-node/releases/download/v24.2.0/node-v24.2.0-openharmony-arm64.tar.gz
tar -zxf node-v24.2.0-openharmony-arm64.tar.gz -C /opt
rm node-v24.2.0-openharmony-arm64.tar.gz

# 把所有的命令都软链接一份到 /bin 目录下
find /opt -maxdepth 2 -type d | grep "arm64/bin$" | while IFS= read -r dir; do
    cd "$dir"
    ls | /opt/busybox-1.37.0-ohos-arm64/bin/busybox xargs -I {} sh -c "ln -s -f $(realpath {}) /bin/{}"
    cd - >/dev/null
done

# 下载 ohos-sdk
sdk_download_url="https://cidownload.openharmony.cn/version/Master_Version/ohos-sdk-public_ohos/20260108_020526/version-Master_Version-ohos-sdk-public_ohos-20260108_020526-ohos-sdk-public_ohos.tar.gz"
curl -fSL -o ohos-sdk.tar.gz $sdk_download_url
mkdir /opt/ohos-sdk
tar -zxf ohos-sdk.tar.gz -C /opt/ohos-sdk
rm -f ohos-sdk.tar.gz
cd /opt/ohos-sdk/ohos
busybox unzip -q native-ohos-x64-6.1.0.27-Canary1.zip # 这是官方的命名错误，这里写 x64，实际上里面的制品是 arm64
busybox unzip -q toolchains-ohos-x64-6.1.0.27-Canary1.zip
rm -rf *.zip
cd - >/dev/null

# 官方打出来的包有问题，没有可执行权限，规避一下，自己加上
chmod 0755 /opt/ohos-sdk/ohos/native/llvm/bin/*
chmod 0755 /opt/ohos-sdk/ohos/toolchains/lib/binary-sign-tool

# 把 llvm 里面的命令封装一份放到 /bin 目录下，只封装必要的工具
# clang 和 clang++ 软链接之后不能用，为了很照顾这两个文件，所有文件统一采用这种封装的方案
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
    cat <<EOF > /bin/$executable
#!/bin/sh
exec /opt/ohos-sdk/ohos/native/llvm/bin/$executable "\$@"
EOF
    chmod 0755 /bin/$executable
done

# 把签名工具也软链接到 /bin 目录
ln -s /opt/ohos-sdk/ohos/toolchains/lib/binary-sign-tool /bin/binary-sign-tool

# 对 llvm 进行软链接，生成 cc、gcc、ld、binutils
cd /bin
ln -s clang cc
ln -s clang gcc
ln -s clang++ c++
ln -s clang++ g++
ln -s ld.lld ld
ln -s llvm-addr2line addr2line
ln -s llvm-ar ar
ln -s llvm-cxxfilt c++filt
ln -s llvm-nm nm
ln -s llvm-objcopy objcopy
ln -s llvm-objdump objdump
ln -s llvm-ranlib ranlib
ln -s llvm-readelf readelf
ln -s llvm-size size
ln -s llvm-strip strip
cd - >/dev/null
