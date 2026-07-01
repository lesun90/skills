# skills

A personal skill library for AI coding agents. Skills are reference guides that teach agents proven techniques, patterns, and workflows. This repo ships an `install.sh` script that links skills into any project without committing them.

`skills/<skill-name>/` is the single source of truth. By default, agent-native directories such as `.claude/skills/` and `.agents/skills/` contain symlinks to the shared cache, so editing through either agent path updates the same skill content.

## Bootstrap (once per machine)

```bash
curl -sL https://raw.githubusercontent.com/lesun90/skills/main/install.sh -o ~/install.sh
chmod +x ~/install.sh
```

Update the downloaded installer itself at any time:

```bash
~/install.sh --update
```

On first run the script clones the skills repo into `~/.local/share/skills`. Subsequent runs fetch the latest skills from the remote.

If the cache has tracked local edits, `install.sh` skips the remote refresh and keeps those edits intact.

## Install into a project (per project)

From any project repo root:

```bash
~/install.sh           # all agents (default)
~/install.sh claude    # Claude Code only
~/install.sh codex     # Codex only
```

Each install automatically fetches the latest skills from this repository. If
same-name skills are already installed, the script warns and asks for confirmation
before replacing them. Skills that do not come from this repository remain intact.

To install real copied directories instead of symlinks:

```bash
SKILLS_INSTALL_MODE=copy ~/install.sh
```

## What install does

The installer refreshes its local repository cache, then installs the selected
agent skills. A cache with tracked local edits is never forcibly reset.

| Output | Agent | Purpose |
|--------|-------|---------|
| `.claude/skills/<skill-name>/` | Claude Code | Symlink to the shared cache, discovered via the `Skill` tool |
| `.agents/skills/<skill-name>/` | Codex | Symlink to the shared cache, discovered automatically at session start |
| `.git/info/exclude` entries | — | Keeps generated files out of git without touching `.gitignore` |

## Skills

| Skill | What it covers |
|-------|---------------|
| `brainstorming` | Structured ideation before starting implementation |
| `dispatching-parallel-agents` | Running subagents concurrently for independent tasks |
| `executing-plans` | Following implementation plans task-by-task with review |
| `finishing-a-development-branch` | Pre-PR checklist for branches |
| `receiving-code-review` | How to respond to and act on code review feedback |
| `requesting-code-review` | How to request and frame a code review |
| `subagent-driven-development` | Full development workflow using subagents |
| `systematic-debugging` | Root-cause tracing, condition-based waiting, defense-in-depth |
| `test-driven-development` | RED-GREEN-REFACTOR discipline with anti-rationalization guardrails |
| `using-git-worktrees` | Parallel work across branches without stashing |
| `using-superpowers` | How agents discover and invoke skills |
| `verification-before-completion` | Checklist before declaring any task done |
| `writing-skills` | TDD-based process for creating and testing new skills |

## Repo layout

```
skills/
  install.sh           # installer script
  install              # compatibility wrapper
  skills/
    <skill-name>/
      SKILL.md         # main reference (required)
      ...              # supporting files (optional)
  tests/
    run_tests.sh       # test suite for the installer
  design_doc.md        # design decisions for the installer
```

## Running tests

```bash
bash tests/run_tests.sh
```

## Adding a skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`)
2. Follow the `writing-skills` skill for the full TDD-based authoring process
3. Run `~/install.sh` in any project to pick up the new skill

With the default symlink install, editing `.claude/skills/<skill-name>/` or `.agents/skills/<skill-name>/` edits the shared cache entry at `~/.local/share/skills/skills/<skill-name>/`.

## Adding a platform

Supported platforms are defined once in `install.sh` using `name:destination:exclude-entry` rows. Add one row to the platform registry and matching installer tests; the install loop and exclude handling are shared across platforms.

## Syncing vendor skills

Vendor skills can be synced into this repo with:

```bash
bash scripts/sync-vendor-skills.sh
```

Configured vendors live in `vendors/sources.conf`:

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

Syncing is vendor-authoritative: matching local skill directories are overwritten,
and vendor-only skills are added into local `skills/`. Add another vendor by adding a row to
`vendors/sources.conf`. `path` defaults to `skills` when omitted. Use `path = .`
for repositories that put `SKILL.md` at the repository root.

The GitHub Action `Sync vendor skills` runs weekly, after changes to
`vendors/sources.conf` land on the default branch, and can also be started
manually. It commits vendor updates directly to this repo.
