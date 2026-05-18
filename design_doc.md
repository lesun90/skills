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

A single executable script `install` at the root of the skills repo.
On any new machine, clone the skills repo once. On any new project, run the script
from the project root. Nothing else is needed.

---

## Skills Repo Layout

```
~/skills/
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
git clone git@github.com:<you>/skills.git ~/skills
```

---

## Usage (per project)

From any project repo root:

```bash
~/skills/install           # all agents (default)
~/skills/install claude    # Claude Code only
~/skills/install codex     # Codex only
```

---

## What `install` Does

### 1. Self-update

```
git -C ~/skills pull --ff-only
```

Ensures skills are up to date before copying. Fast-forward only to avoid
surprises on shared machines.

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
# Agent skills (managed by ~/skills/install)
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
| `~/skills` missing | Print clone instructions, exit 1 |
| Unknown agent argument | Print usage, exit 1 |
| `git pull` fails (no network) | Warn and continue with local copy |
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
