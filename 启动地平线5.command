#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

choose() {
    local prompt="$1"
    shift
    if [[ $# == 1 ]]; then printf '%s\n' "$1"; return; fi
    PS3="${prompt}（输入编号）: "
    select choice in "$@"; do
        [[ -n "$choice" ]] || continue
        printf '%s\n' "$choice"
        return
    done
}

root="$HOME/Library/Application Support/CrossOver/Bottles"
bottles=()
for candidate in "$root"/*; do
    [[ -f "$candidate/cxbottle.conf" ]] || continue
    awk '/^[[:space:]]*"Preview"[[:space:]]*=[[:space:]]*"1"/ { found=1 } END { exit !found }' "$candidate/cxbottle.conf" || continue
    bottles+=("${candidate##*/}")
done
if [[ ${#bottles[@]} == 0 ]]; then
    echo '请先在 CrossOver Preview 中启用装有 Steam 和地平线 5 的容器。'
    exit 1
fi
name="$(choose '选择游戏容器' "${bottles[@]}")"
bottle="$root/$name"
if [[ "${1:-}" == --restore ]]; then
    exec /bin/bash ./patch.sh restore "$bottle"
fi

steam="$(/bin/bash ./find-steam.sh "$bottle")"
if [[ -z "$steam" || "$steam" == *$'\n'* ]]; then
    if [[ -n "$steam" ]]; then
        choices=()
        while IFS= read -r candidate; do choices+=("$candidate"); done <<< "$steam"
        steam="$(choose '选择该容器使用的 Steam' "${choices[@]}" '手动指定')"
    fi
    if [[ -z "$steam" || "$steam" == '手动指定' ]]; then
        echo '请输入实际 steam.exe 的 macOS 完整路径（不用加引号），然后按回车。'
        IFS= read -r steam
    fi
fi
printf '容器：%s\nSteam：%s\n' "$name" "$steam"
exec /bin/bash ./patch.sh launch "$bottle" "$steam" "${FH5_PREVIEW_APP:-/Applications/CrossOver Preview.app}"
