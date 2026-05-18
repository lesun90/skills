# `git-skills` Skill Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a single bash `install` script at the skills repo root that copies all skills into agent-native paths (`.claude/commands/` for Claude Code, `AGENTS.md` for Codex) for any project.

**Architecture:** A single executable `install` bash script that: (1) verifies preconditions, (2) self-updates via `git pull --ff-only`, (3) iterates over `$SKILLS_DIR/skills/*/SKILL.md` copying each to `.claude/commands/<skill>.md` and accumulating content for `AGENTS.md`, (4) writes `AGENTS.md` with idempotent `## Skills` section replacement, and (5) adds `.claude/` and `AGENTS.md` to `.gitignore`. `SKILLS_DIR` defaults to the script's own directory, making tests easy to isolate with fake repos.

**Tech Stack:** Bash 4+, pure-bash test runner (zero external dependencies)

---

## File Structure

| File | Responsibility |
|---|---|
| `install` | Main installer script — all install logic lives here |
| `tests/run_tests.sh` | Pure-bash test runner with helpers; imports no external framework |

---

### Task 1: Test runner + "not in git repo" exit 1

**Files:**
- Create: `tests/run_tests.sh`
- Create: `install`

- [ ] **Step 1: Write the failing test**

Create `tests/run_tests.sh`:

```bash
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

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run to verify the test fails**

```bash
bash tests/run_tests.sh
```

Expected output:
```
FAIL: exits 1 when not in a git repo
  expected exit 1, got 127
...
Results: 0 passed, 1 failed
```

(Exit code 127 = file not found, since `install` doesn't exist yet.)

- [ ] **Step 3: Create the script skeleton with the git repo check**

Create `install`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SKILLS_DIR="${SKILLS_DIR:-$(cd "$(dirname "$0")" && pwd)}"

if ! git -C "$(pwd)" rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: not inside a git repository. Run from your project root." >&2
    exit 1
fi

echo "Done."
```

```bash
chmod +x install
```

- [ ] **Step 4: Run to verify the test passes**

```bash
bash tests/run_tests.sh
```

Expected output:
```
PASS: exits 1 when not in a git repo

Results: 1 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add install tests/run_tests.sh
git commit -m "feat: install script skeleton with git repo check"
```

---

### Task 2: "Skills dir missing" exit 1

**Files:**
- Modify: `install`
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/run_tests.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run to verify the test fails**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
FAIL: exits 1 when skills dir is missing
  expected exit 1, got 0
```

- [ ] **Step 3: Add skills dir check to `install`**

In `install`, after the git repo check and before `echo "Done."`:

```bash
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "error: skills repo not found at $SKILLS_DIR" >&2
    printf 'Bootstrap: git clone git@github.com:<you>/skills.git ~/skills\n' >&2
    exit 1
fi
```

- [ ] **Step 4: Run to verify both tests pass**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing

Results: 2 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add install tests/run_tests.sh
git commit -m "feat: exit 1 when skills repo is missing"
```

---

### Task 3: Self-update (git pull --ff-only, warn on failure)

**Files:**
- Modify: `install`
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/run_tests.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run to verify the test fails**

```bash
bash tests/run_tests.sh
```

Expected: 2 passed, 1 failed (no warning in output since pull logic isn't added yet).

- [ ] **Step 3: Add self-update to `install`**

In `install`, after the skills dir check and before `echo "Done."`:

```bash
if ! git -C "$SKILLS_DIR" pull --ff-only >/dev/null 2>&1; then
    echo "warning: git pull --ff-only failed, continuing with local copy" >&2
fi
```

- [ ] **Step 4: Run to verify all 3 tests pass**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing
PASS: warns on git pull failure and continues

Results: 3 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add install tests/run_tests.sh
git commit -m "feat: self-update via git pull --ff-only, warn on failure"
```

---

### Task 4: Claude Code commands installation

**Files:**
- Modify: `install`
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/run_tests.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run to verify the test fails**

```bash
bash tests/run_tests.sh
```

Expected: 3 passed, 1 failed (`.claude/commands/` files not created).

- [ ] **Step 3: Add Claude commands installation to `install`**

Replace `echo "Done."` in `install` with the skill-loop (we'll add back the Done message in the final task):

```bash
COMMANDS_DIR="$(pwd)/.claude/commands"
mkdir -p "$COMMANDS_DIR"

for skill_dir in "$SKILLS_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
        echo "warning: $skill_name has no SKILL.md, skipping" >&2
        continue
    fi

    cp "$skill_md" "$COMMANDS_DIR/$skill_name.md"
done

echo "Done."
```

- [ ] **Step 4: Run to verify all 4 tests pass**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing
PASS: warns on git pull failure and continues
PASS: copies SKILL.md files to .claude/commands/

Results: 4 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add install tests/run_tests.sh
git commit -m "feat: copy SKILL.md files to .claude/commands/"
```

---

### Task 5: Skip skills with no SKILL.md (warn)

**Files:**
- Modify: `tests/run_tests.sh`

(The skip logic is already present in Task 4's loop — this task adds a test to verify it.)

- [ ] **Step 1: Write the failing test**

Append to `tests/run_tests.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run to verify the test passes**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing
PASS: warns on git pull failure and continues
PASS: copies SKILL.md files to .claude/commands/
PASS: skips skill folders with no SKILL.md and warns

Results: 5 passed, 0 failed
```

(Test should pass already — the logic was added in Task 4.)

- [ ] **Step 3: Commit**

```bash
git add tests/run_tests.sh
git commit -m "test: verify missing SKILL.md is skipped with a warning"
```

---

### Task 6: AGENTS.md creation and idempotent update

**Files:**
- Modify: `install`
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Write failing tests**

Append to `tests/run_tests.sh` before the summary block:

```bash
test_agents_md_created() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null

    assert_file_exists "$project/AGENTS.md" || return 1
    assert_file_contains "$project/AGENTS.md" "## Skills" || return 1
    assert_file_contains "$project/AGENTS.md" "### foo" || return 1
    assert_file_contains "$project/AGENTS.md" "foo content" || return 1
    assert_file_contains "$project/AGENTS.md" "### bar" || return 1
}

run_test "creates AGENTS.md with ## Skills section" test_agents_md_created

test_agents_md_idempotent() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null
    run_install "$project" "$skills" >/dev/null  # run twice

    # ## Skills should appear exactly once
    local count
    count=$(grep -c "^## Skills" "$project/AGENTS.md")
    if [[ "$count" -ne 1 ]]; then
        _fail_msg+="  ## Skills appears $count times, expected 1\n"
        return 1
    fi
}

run_test "AGENTS.md ## Skills section is not duplicated on re-run" test_agents_md_idempotent

test_agents_md_preserves_existing_content() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    # Pre-create AGENTS.md with existing content
    printf '# My Project\n\nExisting project notes.\n' > "$project/AGENTS.md"

    run_install "$project" "$skills" >/dev/null

    assert_file_contains "$project/AGENTS.md" "# My Project" || return 1
    assert_file_contains "$project/AGENTS.md" "Existing project notes." || return 1
    assert_file_contains "$project/AGENTS.md" "## Skills" || return 1
}

run_test "AGENTS.md preserves existing content before ## Skills" test_agents_md_preserves_existing_content
```

- [ ] **Step 2: Run to verify the tests fail**

```bash
bash tests/run_tests.sh
```

Expected: 5 passed, 3 failed.

- [ ] **Step 3: Add AGENTS.md generation to `install`**

Update the skill-loop and the section after it in `install`. Replace everything from `COMMANDS_DIR=...` through `echo "Done."` with:

```bash
COMMANDS_DIR="$(pwd)/.claude/commands"
AGENTS_FILE="$(pwd)/AGENTS.md"

mkdir -p "$COMMANDS_DIR"

skills_section="## Skills"$'\n'"<!-- managed by $SKILLS_DIR/install -->"

for skill_dir in "$SKILLS_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
        echo "warning: $skill_name has no SKILL.md, skipping" >&2
        continue
    fi

    # Claude Code
    cp "$skill_md" "$COMMANDS_DIR/$skill_name.md"

    # Codex: accumulate under per-skill heading
    skills_section+=$'\n\n'"### $skill_name"$'\n\n'"$(cat "$skill_md")"
done

# Write AGENTS.md — replace ## Skills section if it exists, preserve content above it
if [[ -f "$AGENTS_FILE" ]]; then
    prefix=$(awk '/^## Skills/{exit} {print}' "$AGENTS_FILE")
else
    prefix=""
fi

{
    [[ -n "$prefix" ]] && printf '%s\n\n' "$prefix"
    printf '%s\n' "$skills_section"
} > "$AGENTS_FILE"

echo "Done."
```

- [ ] **Step 4: Run to verify all 8 tests pass**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing
PASS: warns on git pull failure and continues
PASS: copies SKILL.md files to .claude/commands/
PASS: skips skill folders with no SKILL.md and warns
PASS: creates AGENTS.md with ## Skills section
PASS: AGENTS.md ## Skills section is not duplicated on re-run
PASS: AGENTS.md preserves existing content before ## Skills

Results: 8 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add install tests/run_tests.sh
git commit -m "feat: generate AGENTS.md with idempotent ## Skills section"
```

---

### Task 7: `.gitignore` update (idempotent)

**Files:**
- Modify: `install`
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Write failing tests**

Append to `tests/run_tests.sh` before the summary block:

```bash
test_gitignore_entries_added() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null

    assert_file_contains "$project/.gitignore" ".claude/" || return 1
    assert_file_contains "$project/.gitignore" "AGENTS.md" || return 1
}

run_test "adds .claude/ and AGENTS.md to .gitignore" test_gitignore_entries_added

test_gitignore_idempotent() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    run_install "$project" "$skills" >/dev/null
    run_install "$project" "$skills" >/dev/null  # run twice

    local count
    count=$(grep -cxF ".claude/" "$project/.gitignore")
    if [[ "$count" -ne 1 ]]; then
        _fail_msg+="  .claude/ appears $count times in .gitignore, expected 1\n"
        return 1
    fi
    count=$(grep -cxF "AGENTS.md" "$project/.gitignore")
    if [[ "$count" -ne 1 ]]; then
        _fail_msg+="  AGENTS.md appears $count times in .gitignore, expected 1\n"
        return 1
    fi
}

run_test ".gitignore entries are not duplicated on re-run" test_gitignore_idempotent

test_gitignore_preserves_existing() {
    local tmp="$1"
    local project="$tmp/project"
    local skills="$tmp/skills"
    make_project "$project"
    make_skills_repo "$skills"

    printf 'node_modules/\n*.log\n' > "$project/.gitignore"

    run_install "$project" "$skills" >/dev/null

    assert_file_contains "$project/.gitignore" "node_modules/" || return 1
    assert_file_contains "$project/.gitignore" "*.log" || return 1
    assert_file_contains "$project/.gitignore" ".claude/" || return 1
}

run_test ".gitignore preserves existing entries" test_gitignore_preserves_existing
```

- [ ] **Step 2: Run to verify the tests fail**

```bash
bash tests/run_tests.sh
```

Expected: 8 passed, 3 failed.

- [ ] **Step 3: Add `.gitignore` update to `install`**

In `install`, after the `AGENTS_FILE` block and before `echo "Done."`:

```bash
GITIGNORE="$(pwd)/.gitignore"
touch "$GITIGNORE"

_append_if_missing() {
    local entry="$1" file="$2"
    grep -qxF "$entry" "$file" || echo "$entry" >> "$file"
}

if ! grep -qF "# Agent skills" "$GITIGNORE"; then
    printf '\n# Agent skills (managed by %s/install)\n' "$SKILLS_DIR" >> "$GITIGNORE"
fi
_append_if_missing ".claude/" "$GITIGNORE"
_append_if_missing "AGENTS.md" "$GITIGNORE"
```

- [ ] **Step 4: Run to verify all 11 tests pass**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing
PASS: warns on git pull failure and continues
PASS: copies SKILL.md files to .claude/commands/
PASS: skips skill folders with no SKILL.md and warns
PASS: creates AGENTS.md with ## Skills section
PASS: AGENTS.md ## Skills section is not duplicated on re-run
PASS: AGENTS.md preserves existing content before ## Skills
PASS: adds .claude/ and AGENTS.md to .gitignore
PASS: .gitignore entries are not duplicated on re-run
PASS: .gitignore preserves existing entries

Results: 11 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add install tests/run_tests.sh
git commit -m "feat: update .gitignore with .claude/ and AGENTS.md entries"
```

---

### Task 8: Integration test — full run against actual skills repo

**Files:**
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Write the integration test**

Append to `tests/run_tests.sh` before the summary block:

```bash
test_full_run_with_real_skills() {
    local tmp="$1"
    local project="$tmp/project"
    # Use the actual skills repo (the one containing install)
    local skills
    skills="$(cd "$(dirname "$INSTALL")" && pwd)"
    make_project "$project"

    local output exit_code
    output=$(run_install "$project" "$skills") && exit_code=$? || exit_code=$?

    assert_exit 0 "$exit_code" || return 1
    assert_contains "Done." "$output" || return 1

    # At least one .md file should exist in .claude/commands/
    local count
    count=$(find "$project/.claude/commands" -name "*.md" 2>/dev/null | wc -l)
    if [[ "$count" -lt 1 ]]; then
        _fail_msg+="  expected at least 1 file in .claude/commands/, found $count\n"
        return 1
    fi

    # AGENTS.md and .gitignore should be present
    assert_file_exists "$project/AGENTS.md" || return 1
    assert_file_exists "$project/.gitignore" || return 1
    assert_file_contains "$project/.gitignore" ".claude/" || return 1

    # Re-run should be idempotent
    run_install "$project" "$skills" >/dev/null
    local count2
    count2=$(grep -c "^## Skills" "$project/AGENTS.md")
    if [[ "$count2" -ne 1 ]]; then
        _fail_msg+="  ## Skills duplicated after re-run: found $count2\n"
        return 1
    fi
}

run_test "full run against real skills repo is idempotent" test_full_run_with_real_skills
```

- [ ] **Step 2: Run all tests including the integration test**

```bash
bash tests/run_tests.sh
```

Expected:
```
PASS: exits 1 when not in a git repo
PASS: exits 1 when skills dir is missing
PASS: warns on git pull failure and continues
PASS: copies SKILL.md files to .claude/commands/
PASS: skips skill folders with no SKILL.md and warns
PASS: creates AGENTS.md with ## Skills section
PASS: AGENTS.md ## Skills section is not duplicated on re-run
PASS: AGENTS.md preserves existing content before ## Skills
PASS: adds .claude/ and AGENTS.md to .gitignore
PASS: .gitignore entries are not duplicated on re-run
PASS: .gitignore preserves existing entries
PASS: full run against real skills repo is idempotent

Results: 12 passed, 0 failed
```

- [ ] **Step 3: Smoke-test manually in this repo**

```bash
# From the skills repo root itself — exercises the real path
mkdir /tmp/smoke-test-project
git init /tmp/smoke-test-project
(cd /tmp/smoke-test-project && bash "$(pwd)/install")
ls /tmp/smoke-test-project/.claude/commands/
cat /tmp/smoke-test-project/AGENTS.md | head -20
cat /tmp/smoke-test-project/.gitignore
rm -rf /tmp/smoke-test-project
```

Expected: one `.md` per skill in `commands/`, `AGENTS.md` with `## Skills` section, `.gitignore` with `.claude/` and `AGENTS.md`.

- [ ] **Step 4: Commit**

```bash
git add tests/run_tests.sh
git commit -m "test: integration test against real skills repo"
```

---

## Self-Review

**Spec coverage check:**

| Requirement | Covered by |
|---|---|
| Single `install` script at repo root | Tasks 1–4 |
| Self-update via `git pull --ff-only` | Task 3 |
| Warn (not fail) when pull fails | Task 3 |
| Copy `SKILL.md` → `.claude/commands/<name>.md` | Task 4 |
| Skip skills with no `SKILL.md`, warn | Task 5 |
| Append skills to `AGENTS.md` under `## Skills` | Task 6 |
| `AGENTS.md` idempotent (section replaced not duplicated) | Task 6 |
| `AGENTS.md` preserves pre-existing content | Task 6 |
| Add `.claude/` and `AGENTS.md` to `.gitignore` | Task 7 |
| `.gitignore` entries only appended if missing | Task 7 |
| Exit 1 if not in git repo | Task 1 |
| Exit 1 if `~/skills` missing, print clone instructions | Task 2 |
| `SKILLS_DIR` defaults to script's own directory | Task 1 (script skeleton) |

All requirements covered. No placeholders in any step.
