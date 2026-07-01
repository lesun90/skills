#!/usr/bin/env bash
set -euo pipefail

SKILLS_REPO="${SKILLS_REPO:-git@github.com:lesun90/skills.git}"
SKILLS_CACHE="${SKILLS_CACHE:-$HOME/.local/share/skills}"
SKILLS_INSTALL_MODE="${SKILLS_INSTALL_MODE:-symlink}"
INSTALL_SCRIPT_URL="${INSTALL_SCRIPT_URL:-https://raw.githubusercontent.com/lesun90/skills/main/install.sh}"
AGENT="all"
agent_set=false

PLATFORMS='claude:.claude/skills:.claude/
codex:.agents/skills:.agents/'

usage() {
    cat <<EOF
Usage: install.sh [--update] [claude|codex|all]

Options:
  --update  update this install script from the online repository
EOF
}

update_installer() {
    local script_path temp_file
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    temp_file="$(mktemp "${script_path}.update.XXXXXX")"
    trap 'rm -f "$temp_file"' EXIT

    echo "Updating install script..."
    curl --fail --silent --show-error --location "$INSTALL_SCRIPT_URL" --output "$temp_file"

    if ! bash -n "$temp_file"; then
        echo "error: downloaded install script is not valid Bash; update cancelled" >&2
        exit 1
    fi

    chmod +x "$temp_file"
    mv "$temp_file" "$script_path"
    trap - EXIT
    echo "Install script updated."
}

platform_names() {
    local names="" name destination exclude_entry
    while IFS=: read -r name destination exclude_entry; do
        [[ -n "$name" ]] || continue
        if [[ -z "$names" ]]; then
            names="$name"
        else
            names="$names, $name"
        fi
    done <<< "$PLATFORMS"
    printf '%s' "$names"
}

selected_platforms() {
    local requested="$1"
    local name destination exclude_entry

    if [[ "$requested" == "all" ]]; then
        printf '%s\n' "$PLATFORMS"
        return 0
    fi

    while IFS=: read -r name destination exclude_entry; do
        [[ -n "$name" ]] || continue
        if [[ "$name" == "$requested" ]]; then
            printf '%s:%s:%s\n' "$name" "$destination" "$exclude_entry"
            return 0
        fi
    done <<< "$PLATFORMS"

    return 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update)
            if [[ $# -ne 1 || "$agent_set" == true ]]; then
                echo "error: --update must be used by itself" >&2
                usage >&2
                exit 1
            fi
            update_installer
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            echo "error: unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [[ "$agent_set" == true ]]; then
                echo "error: only one agent target may be specified" >&2
                usage >&2
                exit 1
            fi
            AGENT="$1"
            agent_set=true
            ;;
    esac
    shift
done

SUPPORTED_PLATFORMS="all, $(platform_names)"
SELECTED_PLATFORMS="$(selected_platforms "$AGENT" || true)"

if [[ -z "$SELECTED_PLATFORMS" ]]; then
    echo "error: unknown agent '$AGENT'. Supported: $SUPPORTED_PLATFORMS" >&2
    exit 1
fi

case "$SKILLS_INSTALL_MODE" in
    symlink|copy) ;;
    *) echo "error: unknown install mode '$SKILLS_INSTALL_MODE'. Supported: symlink, copy" >&2; exit 1 ;;
esac

if ! git -C "$(pwd)" rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: not inside a git repository. Run from your project root." >&2
    exit 1
fi

sync_cache() {
    if [[ ! -d "$SKILLS_CACHE/.git" ]]; then
        echo "Cloning skills repo..."
        git clone --quiet "$SKILLS_REPO" "$SKILLS_CACHE"
        return 0
    fi

    if [[ -n "$(git -C "$SKILLS_CACHE" status --porcelain)" ]]; then
        echo "warning: skills cache has local changes, skipping remote refresh" >&2
    elif ! git -C "$SKILLS_CACHE" fetch --quiet origin 2>/dev/null; then
        echo "warning: could not reach remote, using cached copy" >&2
    else
        upstream=$(git -C "$SKILLS_CACHE" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "origin/main")
        git -C "$SKILLS_CACHE" reset --hard "$upstream" --quiet
    fi
}

sync_cache

SKILLS_DIR="$SKILLS_CACHE"
PROJECT_DIR="$(pwd)"

while IFS=: read -r name destination exclude_entry; do
    [[ -n "$name" ]] || continue
    mkdir -p "$PROJECT_DIR/$destination"
done <<< "$SELECTED_PLATFORMS"

overwritten_targets=()
for skill_dir in "$SKILLS_DIR/skills"/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    skill_name="$(basename "$skill_dir")"

    while IFS=: read -r name destination exclude_entry; do
        [[ -n "$name" ]] || continue
        target="$PROJECT_DIR/$destination/$skill_name"
        [[ -e "$target" || -L "$target" ]] && overwritten_targets+=("$target")
    done <<< "$SELECTED_PLATFORMS"
done

if [[ ${#overwritten_targets[@]} -gt 0 ]]; then
    echo "warning: ${#overwritten_targets[@]} installed skill(s) from this repository will be overwritten." >&2
    echo "Local skills whose names are not in this repository will remain intact." >&2
    read -r -p "Continue? [y/N] " reply || reply=""
    case "$reply" in
        y|Y|yes|YES|Yes) ;;
        *) echo "Installation cancelled."; exit 0 ;;
    esac
fi

install_skill() {
    local skill_dir="$1" destination_dir="$2" skill_name="$3"
    local target="$destination_dir/$skill_name"

    rm -rf "$target"

    if [[ "$SKILLS_INSTALL_MODE" == "copy" ]]; then
        cp -r "${skill_dir%/}" "$destination_dir/"
        return 0
    fi

    if ! ln -s "${skill_dir%/}" "$target" 2>/dev/null; then
        echo "warning: could not symlink $skill_name into $destination_dir, copying instead" >&2
        cp -r "${skill_dir%/}" "$destination_dir/"
    fi
}

for skill_dir in "$SKILLS_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
        echo "warning: $skill_name has no SKILL.md, skipping" >&2
        continue
    fi

    while IFS=: read -r name destination exclude_entry; do
        [[ -n "$name" ]] || continue
        install_skill "$skill_dir" "$PROJECT_DIR/$destination" "$skill_name"
    done <<< "$SELECTED_PLATFORMS"
done

GIT_DIR="$(git -C "$PROJECT_DIR" rev-parse --git-dir)"
EXCLUDE_FILE="$GIT_DIR/info/exclude"
mkdir -p "$GIT_DIR/info"
touch "$EXCLUDE_FILE"

_exclude_if_missing() {
    local entry="$1"
    grep -qxF "$entry" "$EXCLUDE_FILE" || echo "$entry" >> "$EXCLUDE_FILE"
}

if ! grep -qF "# Agent skills" "$EXCLUDE_FILE"; then
    printf '\n# Agent skills (managed by skills/install.sh)\n' >> "$EXCLUDE_FILE"
fi

while IFS=: read -r name destination exclude_entry; do
    [[ -n "$name" ]] || continue
    _exclude_if_missing "$exclude_entry"
done <<< "$SELECTED_PLATFORMS"

echo "Done."
