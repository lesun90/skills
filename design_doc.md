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

A single executable script `install.sh` that users download once. On first run it clones
the skills repo into a local cache. On subsequent runs it fetches the latest skills
and reinstalls them. Default installs copy repository skills into project-local
`.skills/` and symlinks agent-native skill directories to that shared project
store so Claude Code and Codex see the same skill content. The legacy
`install` path remains as a compatibility wrapper. No manual `git clone` or
separate bootstrap step is needed.

---

## Skills Repo Layout

```
skills/
  install.sh           # the installer script
  install              # compatibility wrapper
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
curl -sL https://raw.githubusercontent.com/lesun90/skills/main/install.sh -o ~/install.sh
chmod +x ~/install.sh
```

The downloaded installer updates itself atomically from the repository after
validating the new script:

```bash
~/install.sh --upgrade
```

---

## Usage (per project)

From any project repo root:

```bash
~/install.sh           # all agents (default)
~/install.sh claude    # Claude Code only
~/install.sh codex     # Codex only
```

---

## What `install` Does

### 1. Sync skills cache

`SKILLS_CACHE` defaults to `~/.local/share/skills`. On first use the cache does not
exist, so the script clones the repo:

```
git clone https://github.com/lesun90/skills.git ~/.local/share/skills
```

On subsequent runs the cache already exists, so the script fetches and resets:

```
git fetch origin
git reset --hard @{u}
```

If the remote is unreachable, the script warns and continues with the cached copy.
If the cache has tracked local changes, the script warns, skips fetch/reset, and
installs from the dirty cache so edits made through symlinked agent paths are not
lost. Untracked generated files do not block remote refresh.
`SKILLS_REPO` and `SKILLS_CACHE` can both be overridden via environment variables.

### 2. Copy skills into the project-local shared store

Repository skills are copied from the cache into `.skills/<skill-name>/`.
User-created project-local skills also live in `.skills/<skill-name>/`.
This directory is the per-project source of truth for agent skill installs.

### 3. Link skills into agent-native paths

**Claude Code** — `.claude/skills/`

The `.claude/skills/` directory is symlinked to `.skills/` by default. Claude
Code discovers skills in `.claude/skills/` via the `Skill` tool. No Claude
configuration required. New `.skills/<skill-name>/SKILL.md` entries become
visible without rerunning the installer.

**Codex** — `.agents/skills/`

The `.agents/skills/` directory is symlinked to `.skills/` by default. Codex
discovers skills in `.agents/skills/` automatically at session start. No Codex
configuration required. New `.skills/<skill-name>/SKILL.md` entries become
visible without rerunning the installer.

### 4. Record exclusions in `.git/info/exclude`

Appends entries if not already present:

```
# Agent skills (managed by skills/install.sh)
.skills/
.claude/
.agents/
```

`.git/info/exclude` behaves identically to `.gitignore` but lives inside `.git/`
and is never committed. The project's `.gitignore` is left untouched.

---

## Idempotency

Running `install.sh` multiple times in the same repo is safe:

- Skill links or copied directories are removed then recreated (always fresh)
- `.git/info/exclude` entries are only appended if missing

---

## Error Handling

| Condition | Behavior |
|---|---|
| Not inside a git repo | Print error, exit 1 |
| Unknown agent argument | Print usage, exit 1 |
| Unknown install mode | Print usage, exit 1 |
| `--upgrade` or `--update` | Atomically replace the downloaded installer after Bash validation |
| Cache missing + remote unreachable | `git clone` fails, script exits non-zero |
| Cache exists with tracked local changes | Warn and continue with dirty cache |
| Cache exists with untracked generated files only | Fetch and reset, leaving untracked files intact |
| Remote unreachable (cache exists) | Warn and continue with cached copy |
| Skill folder has no `SKILL.md` | Skip that skill, print warning |
| Symlink creation fails | Warn and copy that skill directory instead |

---

## Agent Coverage

| Agent | Native path | Config required? |
|---|---|---|
| Claude Code | `.claude/skills/` | None |
| Codex | `.agents/skills/` | None |

Additional agents can be added to `install.sh` later without changing the skills
repo structure. Supported agents are defined in one `name:destination:exclude-entry`
registry inside `install.sh`.

---

## Install Mode

The default install mode is `symlink`, which points each selected agent-native
skills directory at `.skills/`. Editing `.skills/<skill-name>/` updates the skill
content seen by every selected agent, and adding a new `.skills/<skill-name>/`
is immediately visible through the agent skill directories.

Set `SKILLS_INSTALL_MODE=copy` to install real copied directories instead:

```bash
SKILLS_INSTALL_MODE=copy ~/install.sh
```

---

## Non-Goals

- No selective skill install (all skills or none — per-skill filtering is future work)
- No per-platform install mode differences; every platform uses the selected global mode
- No system-wide PATH modification
- No support for Windows (bash script, macOS/Linux only)

---

## Vendor Sync

Vendor skill sources are configured in `vendors/sources.conf` with one block per
vendor:

```ini
[superpowers]
repo = https://github.com/obra/superpowers.git

[taste-skill]
repo = https://github.com/Leonxlnx/taste-skill

[ui-ux-pro-max-skill]
repo = https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
path = .claude/skills

[stop-slop]
repo = https://github.com/hardikpandya/stop-slop
path = .
```

The default vendor is `obra/superpowers`, syncing its `skills/` directory into
this repo's `skills/` directory. Every vendor sync targets local `skills/`.
Syncing is vendor-authoritative: matching local skill directories are removed
and replaced, and new vendor skills are added. `path` defaults to `skills` when
omitted. Vendors with a root-level `SKILL.md` use `path = .` and are synced into
`skills/<vendor-name>/`.

`scripts/sync-vendor-skills.sh` reads the manifest, clones each vendor into a
temporary directory, and syncs immediate child directories from `path` that
contain `SKILL.md`. If `path` itself contains `SKILL.md`, that directory is
synced as one skill named after the vendor section. Entries without `SKILL.md`
are skipped with a warning.

The `Sync vendor skills` GitHub Action runs the script weekly, after changes to
`vendors/sources.conf` land on the default branch, and on manual dispatch. It
then commits vendor updates directly to this repo.
