#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$REPO_ROOT/install"
INSTALL_SH="$REPO_ROOT/install.sh"

# ── assertion helpers ────────────────────────────────────────────────────────

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

assert_file_not_exists() {
    if [[ -e "$1" ]]; then
        _fail_msg+="  expected path to not exist: $1\n"
        return 1
    fi
}

assert_symlink_exists() {
    if [[ ! -L "$1" ]]; then
        _fail_msg+="  expected symlink to exist: $1\n"
        return 1
    fi
}

assert_not_symlink() {
    if [[ -L "$1" ]]; then
        _fail_msg+="  expected path to not be a symlink: $1\n"
        return 1
    fi
}

assert_symlink_target() {
    local path="$1" expected="$2" actual
    actual=$(readlink "$path" 2>/dev/null || true)
    if [[ "$actual" != "$expected" ]]; then
        _fail_msg+="  expected symlink '$path' to target '$expected', got '$actual'\n"
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

assert_file_not_contains() {
    local path="$1" needle="$2"
    if grep -qF "$needle" "$path" 2>/dev/null; then
        _fail_msg+="  expected '$path' NOT to contain: '$needle'\n"
        return 1
    fi
}

# ── test runner ──────────────────────────────────────────────────────────────

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

# ── helpers ──────────────────────────────────────────────────────────────────

make_skills_repo() {
    local dir="$1"
    git init -q "$dir"
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
    mkdir -p "$dir/skills/foo" "$dir/skills/bar"
    printf '# Foo Skill\n\nfoo content\n' > "$dir/skills/foo/SKILL.md"
    printf '# Bar Skill\n\nbar content\n' > "$dir/skills/bar/SKILL.md"
    git -C "$dir" add .
    git -C "$dir" commit -q -m "init"
}

make_project() {
    local dir="$1"
    git init -q "$dir"
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
}

# SKILLS_CACHE points to a pre-populated local git repo (bypasses network).
run_install() {
    local project_dir="$1" skills_cache="$2" agent="${3:-}"
    (cd "$project_dir" && SKILLS_CACHE="$skills_cache" bash "$INSTALL_SH" $agent 2>&1)
}

run_install_copy() {
    local project_dir="$1" skills_cache="$2" agent="${3:-}"
    (cd "$project_dir" && SKILLS_CACHE="$skills_cache" SKILLS_INSTALL_MODE=copy bash "$INSTALL_SH" $agent 2>&1)
}

run_fetch() {
    local cwd="$1" skills_cache="$2" skills_repo="$3"
    (cd "$cwd" && SKILLS_CACHE="$skills_cache" SKILLS_REPO="$skills_repo" bash "$INSTALL_SH" --fetch 2>&1)
}

run_fetch_force() {
    local cwd="$1" skills_cache="$2" skills_repo="$3"
    (cd "$cwd" && SKILLS_CACHE="$skills_cache" SKILLS_REPO="$skills_repo" bash "$INSTALL_SH" --fetch --force 2>&1)
}

run_install_wrapper() {
    local project_dir="$1" skills_cache="$2" agent="${3:-}"
    (cd "$project_dir" && SKILLS_CACHE="$skills_cache" bash "$INSTALL" $agent 2>&1)
}

# ── tests ────────────────────────────────────────────────────────────────────

test_not_git_repo() {
    local tmp="$1"
    local project="$tmp/project"
    mkdir "$project"   # deliberately no .git

    local output exit_code
    output=$(cd "$project" && SKILLS_CACHE="$tmp/cache" bash "$INSTALL" 2>&1) && exit_code=$? || exit_code=$?

    assert_exit 1 "$exit_code" || return 1
    assert_contains "git repository" "$output" || return 1
}

run_test "exits 1 when not in a git repo" test_not_git_repo

test_clone_fails_when_unreachable() {
    local tmp="$1"
    local project="$tmp/project"
    make_project "$project"

    # No cache + invalid repo URL → git clone fails → script exits non-zero
    local output exit_code
    output=$(cd "$project" \
        && SKILLS_CACHE="$tmp/cache" SKILLS_REPO="git@github.invalid:nobody/nope.git" \
        bash "$INSTALL" 2>&1) && exit_code=$? || exit_code=$?

    assert_exit 128 "$exit_code" || return 1
    assert_contains "Cloning" "$output" || return 1
}

run_test "exits non-zero when cache is missing and repo is unreachable" test_clone_fails_when_unreachable

test_unknown_agent_arg() {
    local tmp="$1"
    local project="$tmp/project"
    make_project "$project"

    local output exit_code
    output=$(cd "$project" && SKILLS_CACHE="$tmp/cache" bash "$INSTALL" gemini 2>&1) && exit_code=$? || exit_code=$?

    assert_exit 1 "$exit_code" || return 1
    assert_contains "unknown agent" "$output" || return 1
    assert_contains "Supported: all, claude, codex" "$output" || return 1
}

run_test "exits 1 for unknown agent argument" test_unknown_agent_arg

test_install_wrapper_delegates_to_install_sh() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    local output exit_code
    output=$(run_install_wrapper "$project" "$cache" codex) && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1
    assert_file_exists "$project/.agents/skills/foo/SKILL.md" || return 1
    assert_file_not_exists "$project/.claude/skills/foo/SKILL.md" || return 1
}

run_test "install wrapper delegates to install.sh" test_install_wrapper_delegates_to_install_sh

test_default_install_symlinks_to_cache() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" >/dev/null

    assert_symlink_exists "$project/.claude/skills/foo" || return 1
    assert_symlink_exists "$project/.agents/skills/foo" || return 1
    assert_symlink_target "$project/.claude/skills/foo" "$cache/skills/foo" || return 1
    assert_symlink_target "$project/.agents/skills/foo" "$cache/skills/foo" || return 1
    assert_file_contains "$project/.claude/skills/foo/SKILL.md" "Foo Skill" || return 1
    assert_file_contains "$project/.agents/skills/foo/SKILL.md" "Foo Skill" || return 1
}

run_test "default install symlinks skill directories to cache" test_default_install_symlinks_to_cache

test_copy_mode_installs_real_directories() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install_copy "$project" "$cache" >/dev/null

    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.agents/skills/foo/SKILL.md" || return 1
    assert_not_symlink "$project/.claude/skills/foo" || return 1
    assert_not_symlink "$project/.agents/skills/foo" || return 1
}

run_test "copy mode installs real skill directories" test_copy_mode_installs_real_directories

test_no_remote_continues() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"
    # No remote — fetch is skipped silently, install uses local cache

    local output exit_code
    output=$(run_install "$project" "$cache") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1
}

run_test "succeeds with local-only cache (no remote)" test_no_remote_continues

test_dirty_cache_is_not_reset() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    local remote="$tmp/remote.git"
    make_project "$project"
    make_skills_repo "$cache"
    git clone --quiet --bare "$cache" "$remote"
    git -C "$cache" remote add origin "$remote"
    git -C "$cache" fetch --quiet origin
    local branch
    branch=$(git -C "$cache" branch --show-current)
    git -C "$cache" branch --set-upstream-to="origin/$branch" >/dev/null
    printf '# Foo Skill\n\nlocal edit\n' > "$cache/skills/foo/SKILL.md"

    local output exit_code
    output=$(run_install "$project" "$cache") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "cache has local changes" "$output" || return 1
    assert_file_contains "$cache/skills/foo/SKILL.md" "local edit" || return 1
    assert_file_contains "$project/.claude/skills/foo/SKILL.md" "local edit" || return 1
}

run_test "dirty cache is not reset before symlink install" test_dirty_cache_is_not_reset

test_fetch_clones_cache_outside_git_repo() {
    local tmp="$1"
    local source="$tmp/source"
    local cache="$tmp/cache"
    local nongit="$tmp/nongit"
    make_skills_repo "$source"
    mkdir "$nongit"

    local output exit_code
    output=$(run_fetch "$nongit" "$cache" "$source") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Cloning skills repo" "$output" || return 1
    assert_file_exists "$cache/skills/foo/SKILL.md" || return 1
    assert_file_not_exists "$nongit/.claude/skills/foo/SKILL.md" || return 1
    assert_file_not_exists "$nongit/.agents/skills/foo/SKILL.md" || return 1
}

run_test "--fetch clones cache outside a git repo without installing" test_fetch_clones_cache_outside_git_repo

test_fetch_pulls_new_remote_skill() {
    local tmp="$1"
    local source="$tmp/source"
    local cache="$tmp/cache"
    local nongit="$tmp/nongit"
    make_skills_repo "$source"
    mkdir "$nongit"
    run_fetch "$nongit" "$cache" "$source" >/dev/null

    mkdir -p "$source/skills/baz"
    printf '# Baz Skill\n\nbaz content\n' > "$source/skills/baz/SKILL.md"
    git -C "$source" add .
    git -C "$source" commit -q -m "add baz"

    local output exit_code
    output=$(run_fetch "$nongit" "$cache" "$source") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1
    assert_file_exists "$cache/skills/baz/SKILL.md" || return 1
    assert_file_contains "$cache/skills/baz/SKILL.md" "Baz Skill" || return 1
    assert_file_not_exists "$nongit/.claude/skills/baz/SKILL.md" || return 1
}

run_test "--fetch pulls new skills into the cache" test_fetch_pulls_new_remote_skill

test_fetch_preserves_dirty_cache() {
    local tmp="$1"
    local source="$tmp/source"
    local cache="$tmp/cache"
    local nongit="$tmp/nongit"
    make_skills_repo "$source"
    mkdir "$nongit"
    run_fetch "$nongit" "$cache" "$source" >/dev/null
    printf '# Foo Skill\n\nlocal edit\n' > "$cache/skills/foo/SKILL.md"

    local output exit_code
    output=$(run_fetch "$nongit" "$cache" "$source") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "cache has local changes" "$output" || return 1
    assert_file_contains "$cache/skills/foo/SKILL.md" "local edit" || return 1
}

run_test "--fetch preserves dirty cache by default" test_fetch_preserves_dirty_cache

test_fetch_force_resets_dirty_cache() {
    local tmp="$1"
    local source="$tmp/source"
    local cache="$tmp/cache"
    local nongit="$tmp/nongit"
    make_skills_repo "$source"
    mkdir "$nongit"
    run_fetch "$nongit" "$cache" "$source" >/dev/null
    printf '# Foo Skill\n\nlocal edit\n' > "$cache/skills/foo/SKILL.md"

    local output exit_code
    output=$(run_fetch_force "$nongit" "$cache" "$source") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1
    assert_file_contains "$cache/skills/foo/SKILL.md" "foo content" || return 1
    assert_file_not_contains "$cache/skills/foo/SKILL.md" "local edit" || return 1
}

run_test "--fetch --force resets dirty cache" test_fetch_force_resets_dirty_cache

test_claude_skills_created() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" claude >/dev/null

    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.claude/skills/bar/SKILL.md" || return 1
    assert_file_contains "$project/.claude/skills/foo/SKILL.md" "Foo Skill" || return 1
    assert_file_contains "$project/.claude/skills/bar/SKILL.md" "Bar Skill" || return 1
    assert_file_not_exists "$project/.agents/skills/foo/SKILL.md" || return 1
}

run_test "claude: installs skill directories to .claude/skills/" test_claude_skills_created

test_codex_skills_created() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" codex >/dev/null

    assert_file_exists "$project/.agents/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.agents/skills/bar/SKILL.md" || return 1
    assert_file_contains "$project/.agents/skills/foo/SKILL.md" "Foo Skill" || return 1
    assert_file_contains "$project/.agents/skills/bar/SKILL.md" "Bar Skill" || return 1
    assert_file_not_exists "$project/.claude/skills/foo/SKILL.md" || return 1
}

run_test "codex: installs skill directories to .agents/skills/" test_codex_skills_created

test_all_installs_both() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" >/dev/null  # default: all

    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.agents/skills/foo/SKILL.md" || return 1
}

run_test "default (all): installs for both claude and codex" test_all_installs_both

test_skips_skill_without_skill_md() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"
    mkdir -p "$cache/skills/empty-skill"

    local output
    output=$(run_install "$project" "$cache")

    assert_contains "warning" "$output" || return 1
    assert_contains "empty-skill" "$output" || return 1
    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
}

run_test "skips skill folders with no SKILL.md and warns" test_skips_skill_without_skill_md

test_exclude_claude_only() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" claude >/dev/null

    assert_file_contains "$project/.git/info/exclude" ".claude/" || return 1
    assert_file_not_contains "$project/.git/info/exclude" ".agents/" || return 1
}

run_test "claude: adds only .claude/ to .git/info/exclude" test_exclude_claude_only

test_exclude_codex_only() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" codex >/dev/null

    assert_file_contains "$project/.git/info/exclude" ".agents/" || return 1
    assert_file_not_contains "$project/.git/info/exclude" ".claude/" || return 1
}

run_test "codex: adds only .agents/ to .git/info/exclude" test_exclude_codex_only

test_exclude_all() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" >/dev/null

    assert_file_contains "$project/.git/info/exclude" ".claude/" || return 1
    assert_file_contains "$project/.git/info/exclude" ".agents/" || return 1
}

run_test "all: adds both .claude/ and .agents/ to .git/info/exclude" test_exclude_all

test_exclude_idempotent() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    run_install "$project" "$cache" >/dev/null
    run_install "$project" "$cache" >/dev/null  # run twice

    local count
    count=$(grep -cxF ".claude/" "$project/.git/info/exclude")
    if [[ "$count" -ne 1 ]]; then
        _fail_msg+="  .claude/ appears $count times in exclude, expected 1\n"
        return 1
    fi
    count=$(grep -cxF ".agents/" "$project/.git/info/exclude")
    if [[ "$count" -ne 1 ]]; then
        _fail_msg+="  .agents/ appears $count times in exclude, expected 1\n"
        return 1
    fi
}

run_test "exclude entries are not duplicated on re-run" test_exclude_idempotent

test_gitignore_untouched() {
    local tmp="$1"
    local project="$tmp/project"
    local cache="$tmp/cache"
    make_project "$project"
    make_skills_repo "$cache"

    printf 'node_modules/\n*.log\n' > "$project/.gitignore"
    local before after
    before=$(cat "$project/.gitignore")

    run_install "$project" "$cache" >/dev/null

    after=$(cat "$project/.gitignore")
    if [[ "$before" != "$after" ]]; then
        _fail_msg+="  .gitignore was modified\n"
        return 1
    fi
}

run_test ".gitignore is not touched" test_gitignore_untouched

test_full_run_with_real_skills() {
    local tmp="$1"
    local project="$tmp/project"
    local workspace
    workspace="$REPO_ROOT"
    # Clone workspace locally so the install script's git reset --hard
    # operates on the clone, not the workspace itself.
    local cache="$tmp/cache"
    git clone --quiet --local "$workspace" "$cache"
    make_project "$project"

    local output exit_code
    output=$(run_install "$project" "$cache") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1

    local count
    count=$(find -L "$project/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
    if [[ "$count" -lt 1 ]]; then
        _fail_msg+="  expected at least 1 SKILL.md in .claude/skills/, found $count\n"
        return 1
    fi

    assert_file_contains "$project/.git/info/exclude" ".claude/" || return 1

    # Re-run must be idempotent
    run_install "$project" "$cache" >/dev/null
    local count2
    count2=$(find -L "$project/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
    if [[ "$count" -ne "$count2" ]]; then
        _fail_msg+="  skill count changed after re-run: $count → $count2\n"
        return 1
    fi
}

run_test "full run against real skills repo is idempotent" test_full_run_with_real_skills

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
