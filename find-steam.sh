#!/bin/bash
set -euo pipefail
bottle="$1"
for drive in "$bottle/dosdevices/"[a-x]:; do
    [[ -d "$drive" ]] || continue
    for path in 'Program Files (x86)/Steam' 'Program Files/Steam' Steam .; do
        dir="$drive/$path"
        candidate="$dir/steam.exe"
        [[ -f "$candidate" ]] || continue
        [[ "$(/usr/bin/file -bL "$candidate")" == PE32* ]] || continue
        printf '%s/steam.exe\n' "$(cd "$dir" && pwd -P)"
    done
done | awk '!seen[$0]++'
