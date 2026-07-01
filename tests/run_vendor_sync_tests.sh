#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/sync-vendor-skills.sh"

_fail_msg=""

assert_exit() {
    local expected="$1" actual="$2"
    if [[ "$actual" -ne "$expected" ]]; then
        _fail_msg+="  expected exit $expected, got $actual\n"
        return 1
    fi
}

assert_contains() {
    local needle="$1" haystack="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        _fail_msg+="  expected output to contain: '$needle'\n"
        _fail_msg+="  actual: $haystack\n"
        return 1
    fi
}

assert_file_exists() {
    if [[ ! -f "$1" ]]; then
        _fail_msg+="  expected file to exist: $1\n"
        return 1
    fi
}

assert_file_contains() {
    local path="$1" needle="$2"
    if ! grep -qF "$needle" "$path" 2>/dev/null; then
        _fail_msg+="  expected '$path' to contain: '$needle'\n"
        return 1
    fi
}

assert_file_not_exists() {
    if [[ -e "$1" ]]; then
        _fail_msg+="  expected path to not exist: $1\n"
        return 1
    fi
}

run_test() {
    local name="$1" fn="$2"
    local tmpdir
    tmpdir=$(mktemp -d)
    _fail_msg=""
    if "$fn" "$tmpdir"; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $name"
        printf "%b" "$_fail_msg"
        FAIL=$((FAIL + 1))
    fi
    rm -rf "$tmpdir"
}

make_vendor_repo() {
    local dir="$1" skill="$2" content="$3"
    git init -q "$dir"
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
    mkdir -p "$dir/skills/$skill"
    printf '%s\n' "$content" > "$dir/skills/$skill/SKILL.md"
    git -C "$dir" add .
    git -C "$dir" commit -q -m "init"
}

make_root_vendor_repo() {
    local dir="$1" content="$2"
    git init -q "$dir"
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
    printf '%s\n' "$content" > "$dir/SKILL.md"
    mkdir -p "$dir/references"
    printf 'reference content\n' > "$dir/references/example.md"
    git -C "$dir" add .
    git -C "$dir" commit -q -m "init"
}

run_sync() {
    local project="$1" manifest="$2"
    (cd "$project" && VENDOR_SOURCES="$manifest" bash "$SCRIPT" 2>&1)
}

write_vendor_config() {
    local manifest="$1" name="$2" repo="$3" path="${4:-}"
    {
        printf '[%s]\n' "$name"
        printf 'repo = %s\n' "$repo"
        if [[ -n "$path" ]]; then
            printf 'path = %s\n' "$path"
        fi
    } >> "$manifest"
}

test_overwrites_existing_skill() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills/foo"
    printf 'local content\n' > "$project/skills/foo/SKILL.md"
    make_vendor_repo "$vendor" foo "vendor content"
    write_vendor_config "$manifest" vendor "$vendor" skills

    local output exit_code
    output=$(run_sync "$project" "$manifest") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Synced vendor" "$output" || return 1
    assert_file_contains "$project/skills/foo/SKILL.md" "vendor content" || return 1
}

run_test "overwrites existing matching skills" test_overwrites_existing_skill

test_adds_new_vendor_skill() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    make_vendor_repo "$vendor" bar "bar vendor content"
    write_vendor_config "$manifest" vendor "$vendor" skills

    local output exit_code
    output=$(run_sync "$project" "$manifest") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_file_exists "$project/skills/bar/SKILL.md" || return 1
    assert_file_contains "$project/skills/bar/SKILL.md" "bar vendor content" || return 1
}

run_test "adds new vendor-only skills" test_adds_new_vendor_skill

test_syncs_root_level_skill_as_vendor_name() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    make_root_vendor_repo "$vendor" "root skill content"
    write_vendor_config "$manifest" root-skill "$vendor" "."

    local output exit_code
    output=$(run_sync "$project" "$manifest") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Synced vendor" "$output" || return 1
    assert_file_contains "$project/skills/root-skill/SKILL.md" "root skill content" || return 1
    assert_file_exists "$project/skills/root-skill/references/example.md" || return 1
    assert_file_not_exists "$project/skills/root-skill/.git/config" || return 1
}

run_test "syncs root-level SKILL.md as the vendor name" test_syncs_root_level_skill_as_vendor_name

test_processes_multiple_vendors() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor_a="$tmp/vendor-a"
    local vendor_b="$tmp/vendor-b"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    make_vendor_repo "$vendor_a" alpha "alpha content"
    make_vendor_repo "$vendor_b" beta "beta content"
    write_vendor_config "$manifest" a "$vendor_a" skills
    printf '\n' >> "$manifest"
    write_vendor_config "$manifest" b "$vendor_b" skills

    run_sync "$project" "$manifest" >/dev/null

    assert_file_contains "$project/skills/alpha/SKILL.md" "alpha content" || return 1
    assert_file_contains "$project/skills/beta/SKILL.md" "beta content" || return 1
}

run_test "processes multiple vendor rows" test_processes_multiple_vendors

test_missing_source_path_fails() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    make_vendor_repo "$vendor" foo "vendor content"
    write_vendor_config "$manifest" vendor "$vendor" missing

    local output exit_code
    output=$(run_sync "$project" "$manifest") && exit_code=$? || exit_code=$?

    assert_exit 1 "$exit_code" || return 1
    assert_contains "source path not found" "$output" || return 1
}

run_test "fails when vendor source path is missing" test_missing_source_path_fails

test_skips_vendor_entries_without_skill_md() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    git init -q "$vendor"
    git -C "$vendor" config user.email "test@test.com"
    git -C "$vendor" config user.name "Test"
    mkdir -p "$vendor/skills/empty"
    printf 'notes only\n' > "$vendor/skills/empty/README.md"
    git -C "$vendor" add .
    git -C "$vendor" commit -q -m "init"
    write_vendor_config "$manifest" vendor "$vendor" skills

    local output exit_code
    output=$(run_sync "$project" "$manifest") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "skipping empty" "$output" || return 1
    assert_file_not_exists "$project/skills/empty/README.md" || return 1
}

run_test "skips vendor entries without SKILL.md" test_skips_vendor_entries_without_skill_md

test_path_defaults_to_skills() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    make_vendor_repo "$vendor" defaulted "default path content"
    write_vendor_config "$manifest" vendor "$vendor"

    run_sync "$project" "$manifest" >/dev/null

    assert_file_contains "$project/skills/defaulted/SKILL.md" "default path content" || return 1
}

run_test "path defaults to skills when omitted" test_path_defaults_to_skills

test_inline_comments_and_spacing_are_allowed() {
    local tmp="$1"
    local project="$tmp/project"
    local vendor="$tmp/vendor"
    local manifest="$tmp/sources.conf"
    mkdir -p "$project/skills"
    make_vendor_repo "$vendor" commented "commented content"
    {
        printf '# vendor list\n'
        printf '[vendor]\n'
        printf 'repo    =    %s    # local fixture repo\n' "$vendor"
        printf 'path = skills\n'
    } > "$manifest"

    run_sync "$project" "$manifest" >/dev/null

    assert_file_contains "$project/skills/commented/SKILL.md" "commented content" || return 1
}

run_test "comments and flexible spacing are allowed" test_inline_comments_and_spacing_are_allowed

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
