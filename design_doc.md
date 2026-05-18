# Design: `skills` Installer

**Date:** 2026-05-18
**Status:** Approved

---

## Problem

When starting work on a new project repo, agent skills (Claude Code, Codex, etc.) need
to be available locally but must not be committed to the project git history. Skills
live in a personal GitHub skills repo and need to be copied into each project using
agent-native paths so agents work without any reconfiguration.

---

## Solution

A single executable script `install` that users download once. On first run it clones
the skills repo into a local cache. On subsequent runs it fetches the latest skills
and reinstalls them. No manual `git clone` or separate bootstrap step is needed.

---

## Skills Repo Layout

```
skills/
  install              # the installer script
  README.md
  skills/
    skill-name/
      SKILL.md         # main reference (required)
      ...              # supporting files (optional)
  tests/
    run_tests.sh
```

---

## Bootstrap (once per machine)

```bash
curl -sL https://raw.githubusercontent.com/lesun90/skills/main/install -o ~/install
chmod +x ~/install
```

---

## Usage (per project)

From any project repo root:

```bash
~/install           # all agents (default)
~/install claude    # Claude Code only
~/install codex     # Codex only
```

---

## What `install` Does

### 1. Sync skills cache

`SKILLS_CACHE` defaults to `~/.local/share/skills`. On first use the cache does not
exist, so the script clones the repo:

```
git clone git@github.com:lesun90/skills.git ~/.local/share/skills
```

On subsequent runs the cache already exists, so the script fetches and resets:

```
git fetch origin
git reset --hard @{u}
```

If the remote is unreachable, the script warns and continues with the cached copy.
`SKILLS_REPO` and `SKILLS_CACHE` can both be overridden via environment variables.

### 2. Copy skills into agent-native paths

**Claude Code** — `.claude/skills/<skill-name>/`

Each skill directory is copied wholesale. Claude Code discovers skills in
`.claude/skills/` via the `Skill` tool. No Claude configuration required.

**Codex** — `.agents/skills/<skill-name>/`

Each skill directory is copied wholesale. Codex discovers skills in
`.agents/skills/` automatically at session start. No Codex configuration required.

### 3. Record exclusions in `.git/info/exclude`

Appends entries if not already present:

```
# Agent skills (managed by skills/install)
.claude/
.agents/
```

`.git/info/exclude` behaves identically to `.gitignore` but lives inside `.git/`
and is never committed. The project's `.gitignore` is left untouched.

---

## Idempotency

Running `install` multiple times in the same repo is safe:

- Skill directories are removed then re-copied (always fresh)
- `.git/info/exclude` entries are only appended if missing

---

## Error Handling

| Condition | Behavior |
|---|---|
| Not inside a git repo | Print error, exit 1 |
| Unknown agent argument | Print usage, exit 1 |
| Cache missing + remote unreachable | `git clone` fails, script exits non-zero |
| Remote unreachable (cache exists) | Warn and continue with cached copy |
| Skill folder has no `SKILL.md` | Skip that skill, print warning |

---

## Agent Coverage

| Agent | Native path | Config required? |
|---|---|---|
| Claude Code | `.claude/skills/<skill-name>/` | None |
| Codex | `.agents/skills/<skill-name>/` | None |

Additional agents can be added to `install` later without changing the skills
repo structure.

---

## Non-Goals

- No selective skill install (all skills or none — per-skill filtering is future work)
- No symlinks (copied files only, no live sync)
- No system-wide PATH modification
- No support for Windows (bash script, macOS/Linux only)
