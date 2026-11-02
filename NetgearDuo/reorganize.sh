#!/usr/bin/env bash
# Reorganize the NetgearDuo project without deleting original material.
# Usage: ./reorganize.sh --dry-run | --apply
set -Eeuo pipefail

usage() {
    printf 'Usage: %s --dry-run | --apply\n' "$(basename "$0")"
}

if [[ $# -ne 1 ]]; then usage; exit 2; fi
case "$1" in
    --dry-run) APPLY=false ;;
    --apply) APPLY=true ;;
    *) usage; exit 2 ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "$(basename "$SCRIPT_DIR")" == "NetgearDuo" ]]; then
    PROJECT_ROOT="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/NetgearDuo" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/NetgearDuo" && pwd -P)"
else
    printf 'ERROR: Place this script inside NetgearDuo or its parent directory.\n' >&2
    exit 1
fi

GIT_ROOT="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'ERROR: NetgearDuo must be inside a Git working tree.\n' >&2
    exit 1
}
case "$PROJECT_ROOT" in
    "$GIT_ROOT"|"$GIT_ROOT"/*) ;;
    *) printf 'ERROR: Project is outside Git working tree.\n' >&2; exit 1 ;;
esac

printf 'Git root:    %s\nProject root:%s\nMode:        %s\n\n' "$GIT_ROOT" " $PROJECT_ROOT" "$1"

# Avoid accidentally reorganizing while other changes are pending.
if [[ -n "$(git -C "$GIT_ROOT" status --porcelain --untracked-files=no)" ]]; then
    printf 'ERROR: Git has tracked changes. Commit/stash them before continuing.\n' >&2
    exit 1
fi

cd "$PROJECT_ROOT"

# All moves are relative to NetgearDuo.
SOURCES=(readynas_gpl zips RAIDiator-Sparc-4.1.16 TFTP_Boot)
TARGETS=(sources/readynas_gpl archives/zips firmware/RAIDiator-Sparc-4.1.16 firmware/TFTP_Boot)
DIRS=(sources archives firmware scripts reversing/mtd1 reversing/tools documentation/hardware documentation/boot-process documentation/nand-flash documentation/tutorials)

for i in "${!SOURCES[@]}"; do
    src="${SOURCES[$i]}"
    dst="${TARGETS[$i]}"
    if [[ ! -e "$src" && ! -L "$src" ]]; then
        if [[ -e "$dst" || -L "$dst" ]]; then
            printf 'SKIP: already moved: %s\n' "$dst"
        else
            printf 'SKIP: source not found: %s\n' "$src"
        fi
        continue
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        printf 'ERROR: Destination exists, refusing to overwrite: %s\n' "$dst" >&2
        exit 1
    fi
done

# Preview all operations before making changes.
for i in "${!SOURCES[@]}"; do
    src="${SOURCES[$i]}"
    dst="${TARGETS[$i]}"
    [[ -e "$src" || -L "$src" ]] || continue
    printf 'MOVE: %s -> %s\n' "$src" "$dst"
done
for dir in "${DIRS[@]}"; do
    [[ -d "$dir" ]] || printf 'MKDIR: %s\n' "$dir"
done

if [[ "$APPLY" == false ]]; then
    printf '\nDry run only; nothing changed.\n'
    exit 0
fi

# Use mv so tracked, untracked, and ignored files all move together.
# Git detects the tracked renames when changes are staged later.
for i in "${!SOURCES[@]}"; do
    src="${SOURCES[$i]}"
    dst="${TARGETS[$i]}"
    [[ -e "$src" || -L "$src" ]] || continue
    mkdir -p -- "$(dirname -- "$dst")"
    mv -- "$src" "$dst"
done
for dir in "${DIRS[@]}"; do mkdir -p -- "$dir"; done
printf '\nCompleted. No source archives or extracted files were deleted.\n'
printf 'Review: git status --short\n'
printf 'Review: tree -d -L 3\n'

