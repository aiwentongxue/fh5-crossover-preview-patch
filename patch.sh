#!/bin/bash
set -euo pipefail
umask 077

fail() { printf '%s\n' "$*" >&2; exit 1; }
resources="$(cd "$(dirname "$0")" && pwd)"
action="$1"
bottle="$2"
name="${bottle##*/}"
steam="${3:-}"
app="${4:-/Applications/CrossOver Preview.app}"
cx="$app/Contents/SharedSupport/CrossOver"
metal="$cx/lib/apple_gptk/wine"
wine_lib="$cx/lib/wine"
target="$bottle/drive_c/windows/system32/d3d12.dll"
shim="$resources/d3d12.dll"
key="$(printf '%s' "$bottle" | /usr/bin/shasum -a 256 | cut -c1-24)"
state="$HOME/Library/Application Support/FH5 Preview Patch/$key"

[[ -f "$bottle/cxbottle.conf" && -d "${target%/*}" ]] || fail "请选择有效的 CrossOver 容器。"
[[ "$action" == launch || "$action" == restore ]] || fail "未知操作。"
mkdir -p "$state"
mkdir "$state/lock" 2>/dev/null || fail "此容器已有补丁工具任务在运行。"
trap 'rmdir "$state/lock"' EXIT
if ps -axo comm | awk 'tolower($0) ~ /(steam|forzahorizon5)[.]exe$/ { found=1 } END { exit !found }'; then
    fail "请先退出 Windows 版 Steam 和地平线 5，再重试。"
fi

replace_dll() {
    local temporary
    temporary="$(mktemp "${target}.fh5.XXXXXX")"
    if ! cp -p "$1" "$temporary" || ! mv -f "$temporary" "$target"; then
        rm -f "$temporary"
        fail "无法写入容器的 D3D12 文件。"
    fi
}
is_known_patch() {
    cmp -s "$target" "$shim" && return 0
    local hash
    hash="$(/usr/bin/shasum -a 256 < "$target")" || return 1
    # Earlier packages rebuilt the same shim into different binaries.
    case "${hash%% *}" in
        7ba293cd43a499c7cda9061df02d9decc1c82ffca87324307825a514228a39d8|1b8511197500ddf0053d0a827fc1e305072cb6d6e9778404db0543fc02f90f0a|85c90cc640b1e3ae77602cd622f2973796bd86b1a548afe53d96772f85c82b8c|3229c64c9369dfdc06c07b22877d8a955002d9b626e110a19f705c7ba56fe5d3)
            return 0 ;;
        *) return 1 ;;
    esac
}

backup="$state/d3d12.original.dll"
if [[ "$action" == restore ]]; then
    [[ -f "$backup" ]] || fail "此容器没有本工具创建的备份。"
    if cmp -s "$target" "$backup"; then
        printf '%s\n' "原始 D3D12 文件已在容器中。"
        exit
    fi
    [[ -f "$target" && ! -L "$target" ]] && is_known_patch ||
        fail "当前 DLL 无法识别。备份仍在 $state。"
    replace_dll "$backup"
    printf '%s\n' "已恢复原始 D3D12 文件。"
    exit
fi

[[ "$(uname -m)" == arm64 ]] || fail "此补丁面向 Apple 芯片 Mac。"
[[ "$(/usr/bin/sw_vers -productVersion | cut -d. -f1)" -ge 27 ]] || fail "本工具需要 macOS 27 或更新版本。"
[[ -x "$cx/bin/wine" ]] || fail "找不到 CrossOver Preview。"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == 27.0.0.41073 ]] || fail "本包仅适配 CrossOver Preview 构建 27.0.0.41073。"
awk '/^[[:space:]]*"Preview"[[:space:]]*=[[:space:]]*"1"/ { found=1 } END { exit !found }' "$bottle/cxbottle.conf" ||
    fail "请在 CrossOver Preview 中启用这个容器。"
[[ "${steam##*/}" == [Ss][Tt][Ee][Aa][Mm].[Ee][Xx][Ee] && -f "$steam" ]] ||
    fail "请选择 Windows Steam 的 steam.exe。"
[[ "$(/usr/bin/file -bL "$steam")" == PE32* ]] ||
    fail "所选文件不是 Windows 可执行程序。请选择 Steam 安装目录中的 steam.exe。"
[[ -f "$target" && ! -L "$target" && -f "$shim" ]] || fail "缺少可补丁的 D3D12 DLL。"
stock="$metal/x86_64-windows/d3d12.dll"
[[ -f "$stock" && -f "$metal/x86_64-unix/d3d12.so" ]] || fail "Preview 缺少 D3DMetal 4 运行文件。"
[[ "$(/usr/bin/shasum -a 256 "$stock" | cut -d' ' -f1)" == 1e19c9e72d3e835240690035b32b3f64919191e93a428e6f850ad711a3de564d ]] ||
    fail "D3DMetal 文件与本补丁验证的版本不同。"
[[ "$state$metal$wine_lib" != *"'"* && "$state$metal$wine_lib" != *:* ]] || fail "补丁路径或 Preview 路径含单引号或冒号，请移至其他位置。"

mkdir -p "$state/x86_64-windows" "$state/x86_64-unix"
alias_dll="$state/x86_64-windows/apd12.dll"
/usr/bin/perl "$resources/prepare-alias.pl" "$stock" "$alias_dll"
ln -sfn "$metal/x86_64-unix/d3d12.so" "$state/x86_64-unix/apd12.so"
if is_known_patch; then
    [[ -f "$backup" ]] || fail "此容器已有补丁，但本工具缺少原始 DLL 备份。"
    cmp -s "$target" "$shim" || replace_dll "$shim"
else
    # Wine's builtin placeholder can be safely replaced. Preserve existing custom DLLs.
    marker="$(dd if="$target" bs=1 skip=64 count=16 2>/dev/null)"
    [[ "$marker" == 'Wine builtin DLL' ]] || fail "容器已有其他 D3D12 覆盖，请先恢复原始 DLL。"
    if [[ -f "$backup" ]]; then
        cmp -s "$target" "$backup" || fail "容器原始 DLL 已改变，备份保留在 $state。"
    else
        cp -p "$target" "$backup.tmp"
        mv -f "$backup.tmp" "$backup"
    fi
    replace_dll "$shim"
fi

real_d3d12="$(printf 'Z:%s' "$alias_dll" | tr '/' '\\')"
printf '%s\n' "补丁已就绪，正在通过 Steam 启动地平线 5。"
"$cx/bin/wine" --bottle "$name" --no-update \
    --dll 'd3d12=n,b;apd12=b,n' \
    --env "WINEDEBUG=-all,err+all WINEMSYNC=0 WINEESYNC=0 CX_GRAPHICS_BACKEND=d3dmetal CX_GRAPHICS_BACKEND_VERSION=4 WINEDLLPATH='$state:$state/x86_64-windows:$metal:$wine_lib' HB_D3D12_REAL='$real_d3d12' WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--force-device-scale-factor=1" \
    "$steam" -applaunch 1551360
