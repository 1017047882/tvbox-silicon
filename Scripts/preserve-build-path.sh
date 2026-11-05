#!/bin/bash
# @brief Preserve stale build outputs instead of recursively deleting them.
# @note Caller serializes mutations; only paths inside this checkout are accepted.
preserve_build_path() {
  local path root resolved saved
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
  for path in "$@"; do
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then continue; fi
    resolved="$(cd "$(dirname "$path")" && pwd -P)/$(basename "$path")"
    case "$resolved" in
      "$root"/build/*) ;;
      *) echo "Refusing to move output outside build/: $resolved" >&2; return 1 ;;
    esac
    mkdir -p "$root/build/preserved"
    saved="$(mktemp -d "$root/build/preserved/output.XXXXXX")"
    mv "$resolved" "$saved/"
  done
}
