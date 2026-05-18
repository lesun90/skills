# Design: `git-skills` Skill Installer

**Date:** 2026-05-18
**Status:** Approved

---

## Problem

When starting work on a new project repo, agent skills (Claude, Codex, etc.) need
to be available locally but must not be committed to the project git history. Skills
live in a personal GitHub skills repo and need to be copied into each project using
agent-native paths so agents work without any reconfiguration.

---

## Solution

A single executable script `install` that lives at the root of the skills repo.
On any new machine, clone the skills repo once. On any new project, run the script
from the project root. Nothing else is needed.

---

## Skills Repo Layout

```
~/skills/
  install              # the installer script (this design)
  README.md
  coding/
    SKILL.md
    (supporting files)
  brainstorming/
    SKILL.md
    (supporting files)
  scaffolding/
    SKILL.md
  ...
```

---

## Bootstrap (once per machine)

```bash
git clone git@github.com:<you>/skills.git ~/skills
```

The skills repo is always expected at `~/skills`. No PATH changes, no `.gitconfig`
edits, no system-level installs required.

---

## Usage (per project)

From any project repo root:

```bash
~/skills/install
```

That's it.

---

## What `install` Does

### 1. Self-update

```
git -C ~/skills pull --ff-only
```

Ensures skills are up to date before copying. Fast-forward only to avoid
surprises on shared machines.

### 2. Copy skills into agent-native paths

**Claude Code** -- slash commands via `.claude/commands/`

Each skill's `SKILL.md` is copied to `.claude/commands/<skill-name>.md`.
Claude Code discovers these automatically as `/skill-name` commands.
No Claude configuration required.

```
.claude/
  commands/
    coding.md
    brainstorming.md
    scaffolding.md
    ...
```

**Codex** -- `AGENTS.md` at repo root

Each skill's `SKILL.md` content is appended into `AGENTS.md` under a
heading per skill. Codex reads `AGENTS.md` automatically.
If `AGENTS.md` already exists, skills are appended after a `## Skills`
section marker (idempotent: existing marker is replaced, not duplicated).

```
AGENTS.md        # existing project file, skills appended at bottom
```

### 3. Update `.gitignore`

Appends the following entries if not already present:

```
# Agent skills (managed by ~/skills/install)
.claude/
AGENTS.md
```

This ensures neither Claude nor Codex skill files are ever accidentally committed.

---

## Idempotency

Running `install` multiple times in the same repo is safe:

- Files are overwritten (copy is always fresh from skills repo)
- `.gitignore` entries are only appended if missing
- `AGENTS.md` skills section is replaced, not duplicated

---

## Error Handling

| Condition | Behavior |
|---|---|
| Not inside a git repo | Print error, exit 1 |
| `~/skills` missing | Print clone instructions, exit 1 |
| `git pull` fails (no network) | Warn and continue with local copy |
| Skill folder has no `SKILL.md` | Skip that skill, print warning |

---

## Agent Coverage

| Agent | Native path | Config required? |
|---|---|---|
| Claude Code | `.claude/commands/<skill>.md` | None |
| Codex | `AGENTS.md` | None |

Additional agents can be added to `install` later without changing the skills
repo structure.

---

## Non-Goals

- No selective install (all skills or none -- per-project filtering is future work)
- No symlinks (copied files only, no live sync)
- No system-wide PATH modification
- No support for Windows (bash script, macOS/Linux only)