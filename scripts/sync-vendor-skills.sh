#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_SOURCES="${VENDOR_SOURCES:-$ROOT_DIR/vendors/sources.conf}"

if [[ ! -f "$VENDOR_SOURCES" ]]; then
    echo "error: vendor sources file not found: $VENDOR_SOURCES" >&2
    exit 1
fi

tmpdir=$(mktemp -d)
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

sync_vendor() {
    local name="$1" repo="$2" source_path="$3"
    local clone_dir="$tmpdir/$name"
    local source_dir target_dir skill_dir skill_name

    if [[ -z "$name" || -z "$repo" || -z "$source_path" ]]; then
        echo "error: invalid vendor config for $name" >&2
        exit 1
    fi

    echo "Syncing vendor $name..."
    git clone --quiet --depth 1 "$repo" "$clone_dir"

    source_dir="$clone_dir/$source_path"
    target_dir="$ROOT_DIR/skills"

    if [[ ! -d "$source_dir" ]]; then
        echo "error: source path not found for vendor $name: $source_path" >&2
        exit 1
    fi

    mkdir -p "$target_dir"

    for skill_dir in "$source_dir"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"

        if [[ ! -f "$skill_dir/SKILL.md" ]]; then
            echo "warning: skipping $skill_name from $name, no SKILL.md" >&2
            continue
        fi

        rm -rf "$target_dir/$skill_name"
        cp -R "${skill_dir%/}" "$target_dir/"
    done

    echo "Synced vendor $name."
}

strip_comment() {
    local line="$1"
    line="${line%%#*}"
    printf '%s' "$line"
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

sync_current_vendor() {
    if [[ -z "${current_name:-}" ]]; then
        return 0
    fi

    if [[ -z "${current_repo:-}" ]]; then
        echo "error: vendor $current_name is missing repo" >&2
        exit 1
    fi

    sync_vendor "$current_name" "$current_repo" "${current_path:-skills}"
}

current_name=""
current_repo=""
current_path=""

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim "$(strip_comment "$raw_line")")"
    [[ -n "$line" ]] || continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        sync_current_vendor
        current_name="${BASH_REMATCH[1]}"
        current_repo=""
        current_path=""
        continue
    fi

    if [[ -z "$current_name" ]]; then
        echo "error: vendor setting found before section: $line" >&2
        exit 1
    fi

    if [[ "$line" != *=* ]]; then
        echo "error: invalid vendor setting for $current_name: $line" >&2
        exit 1
    fi

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    case "$key" in
        repo) current_repo="$value" ;;
        path) current_path="$value" ;;
        *) echo "error: unknown vendor setting for $current_name: $key" >&2; exit 1 ;;
    esac
done < "$VENDOR_SOURCES"

sync_current_vendor

echo "Done."
