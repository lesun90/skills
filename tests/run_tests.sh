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

assert_file_not_exists() {
    if [[ -e "$1" ]]; then
        _fail_msg+="  expected path to not exist: $1\n"
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
    local project_dir="$1" skills_dir="$2" agent="${3:-}"
    (cd "$project_dir" && SKILLS_DIR="$skills_dir" bash "$INSTALL" $agent 2>&1)
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

test_unknown_agent_arg() {
    local tmp="$1"
    local project="$tmp/project"
    make_project "$project"

    local output exit_code
    output=$(cd "$project" && SKILLS_DIR="$tmp/skills" bash "$INSTALL" gemini 2>&1) && exit_code=$? || exit_code=$?

    assert_exit 1 "$exit_code" || return 1
    assert_contains "unknown agent" "$output" || return 1
}

run_test "exits 1 for unknown agent argument" test_unknown_agent_arg

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

test_claude_skills_created() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" claude >/dev/null

    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.claude/skills/bar/SKILL.md" || return 1
    assert_file_contains "$project/.claude/skills/foo/SKILL.md" "Foo Skill" || return 1
    assert_file_contains "$project/.claude/skills/bar/SKILL.md" "Bar Skill" || return 1
    assert_file_not_exists "$project/.agents/skills/foo/SKILL.md" || return 1
}

run_test "claude: copies skill directories to .claude/skills/" test_claude_skills_created

test_codex_skills_created() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" codex >/dev/null

    assert_file_exists "$project/.agents/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.agents/skills/bar/SKILL.md" || return 1
    assert_file_contains "$project/.agents/skills/foo/SKILL.md" "Foo Skill" || return 1
    assert_file_contains "$project/.agents/skills/bar/SKILL.md" "Bar Skill" || return 1
    assert_file_not_exists "$project/.claude/skills/foo/SKILL.md" || return 1
}

run_test "codex: copies skill directories to .agents/skills/" test_codex_skills_created

test_all_installs_both() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null  # default: all

    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
    assert_file_exists "$project/.agents/skills/foo/SKILL.md" || return 1
}

run_test "default (all): installs for both claude and codex" test_all_installs_both

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
    assert_file_exists "$project/.claude/skills/foo/SKILL.md" || return 1
}

run_test "skips skill folders with no SKILL.md and warns" test_skips_skill_without_skill_md

test_exclude_claude_only() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" claude >/dev/null

    assert_file_contains "$project/.git/info/exclude" ".claude/" || return 1
    assert_file_not_contains "$project/.git/info/exclude" ".agents/" || return 1
}

run_test "claude: adds only .claude/ to .git/info/exclude" test_exclude_claude_only

test_exclude_codex_only() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" codex >/dev/null

    assert_file_contains "$project/.git/info/exclude" ".agents/" || return 1
    assert_file_not_contains "$project/.git/info/exclude" ".claude/" || return 1
}

run_test "codex: adds only .agents/ to .git/info/exclude" test_exclude_codex_only

test_exclude_all() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null

    assert_file_contains "$project/.git/info/exclude" ".claude/" || return 1
    assert_file_contains "$project/.git/info/exclude" ".agents/" || return 1
}

run_test "all: adds both .claude/ and .agents/ to .git/info/exclude" test_exclude_all

test_exclude_idempotent() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null
    run_install "$project" "$skills" >/dev/null  # run twice

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
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    printf 'node_modules/\n*.log\n' > "$project/.gitignore"
    local before after
    before=$(cat "$project/.gitignore")

    run_install "$project" "$skills" >/dev/null

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
    local skills
    skills="$(cd "$(dirname "$INSTALL")" && pwd)"
    make_project "$project"

    local output exit_code
    output=$(run_install "$project" "$skills") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1

    local count
    count=$(find "$project/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
    if [[ "$count" -lt 1 ]]; then
        _fail_msg+="  expected at least 1 SKILL.md in .claude/skills/, found $count\n"
        return 1
    fi
    count=$(find "$project/.agents/skills" -name "SKILL.md" 2>/dev/null | wc -l)
    if [[ "$count" -lt 1 ]]; then
        _fail_msg+="  expected at least 1 SKILL.md in .agents/skills/, found $count\n"
        return 1
    fi

    assert_file_contains "$project/.git/info/exclude" ".claude/" || return 1
    assert_file_contains "$project/.git/info/exclude" ".agents/" || return 1

    # Re-run must be idempotent
    run_install "$project" "$skills" >/dev/null
    count=$(find "$project/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
    local count2
    count2=$(find "$project/.agents/skills" -name "SKILL.md" 2>/dev/null | wc -l)
    if [[ "$count" -ne "$count2" ]]; then
        _fail_msg+="  claude ($count) and codex ($count2) skill counts differ after re-run\n"
        return 1
    fi
}

run_test "full run against real skills repo is idempotent" test_full_run_with_real_skills

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
