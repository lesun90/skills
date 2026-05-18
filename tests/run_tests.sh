#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0
INSTALL="$(cd "$(dirname "$0")/.." && pwd)/install"

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

run_install() {
    local project_dir="$1" skills_dir="$2"
    (cd "$project_dir" && SKILLS_DIR="$skills_dir" bash "$INSTALL" 2>&1)
}

# ── tests ────────────────────────────────────────────────────────────────────

test_not_git_repo() {
    local tmp="$1"
    local project="$tmp/project"
    mkdir "$project"   # deliberately no .git

    local output exit_code
    output=$(cd "$project" && SKILLS_DIR="$tmp/skills" bash "$INSTALL" 2>&1) && exit_code=$? || exit_code=$?

    assert_exit 1 "$exit_code" || return 1
    assert_contains "git repository" "$output" || return 1
}

run_test "exits 1 when not in a git repo" test_not_git_repo

test_skills_dir_missing() {
    local tmp="$1"
    local project="$tmp/project"
    make_project "$project"

    local output exit_code
    output=$(cd "$project" && SKILLS_DIR="$tmp/nonexistent" bash "$INSTALL" 2>&1) && exit_code=$? || exit_code=$?

    assert_exit 1 "$exit_code" || return 1
    assert_contains "not found" "$output" || return 1
    assert_contains "git clone" "$output" || return 1
}

run_test "exits 1 when skills dir is missing" test_skills_dir_missing

test_pull_failure_warns_and_continues() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"
    # Remove the remote so git pull fails
    git -C "$skills" remote remove origin 2>/dev/null || true

    local output exit_code
    output=$(run_install "$project" "$skills") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "warning" "$output" || return 1
    assert_contains "pull" "$output" || return 1
}

run_test "warns on git pull failure and continues" test_pull_failure_warns_and_continues

test_claude_commands_created() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null

    assert_file_exists "$project/.claude/commands/foo.md" || return 1
    assert_file_exists "$project/.claude/commands/bar.md" || return 1
    assert_file_contains "$project/.claude/commands/foo.md" "Foo Skill" || return 1
    assert_file_contains "$project/.claude/commands/bar.md" "Bar Skill" || return 1
}

run_test "copies SKILL.md files to .claude/commands/" test_claude_commands_created

test_skips_skill_without_skill_md() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"
    # Add a skill folder with no SKILL.md
    mkdir -p "$skills/skills/empty-skill"

    local output
    output=$(run_install "$project" "$skills")

    assert_contains "warning" "$output" || return 1
    assert_contains "empty-skill" "$output" || return 1
    # Other skills still installed
    assert_file_exists "$project/.claude/commands/foo.md" || return 1
}

run_test "skips skill folders with no SKILL.md and warns" test_skips_skill_without_skill_md

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
